"""API REST de la Practica 5 (extiende la Practica 2).

Endpoints reutilizados de la Practica 2: /, /register, /login, /notes (CRUD).
Endpoints nuevos: /auth/google, /me, /history, /favorites, /sync, /admin/*.
"""
from datetime import datetime, timedelta, timezone
from functools import wraps
import os

import jwt
import requests
from flask import Flask, jsonify, request
from flask_bcrypt import Bcrypt
from flask_sqlalchemy import SQLAlchemy

app = Flask(__name__)

app.config['SQLALCHEMY_DATABASE_URI'] = os.environ.get('DATABASE_URL', 'sqlite:///site.db')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['JWT_SECRET_KEY'] = os.environ['JWT_SECRET_KEY']
app.config['JWT_EXP_MINUTES'] = int(os.environ.get('JWT_EXP_MINUTES', '60'))

# Usuarios (separados por coma) que obtienen rol admin al registrarse.
ADMIN_USERNAMES = {u.strip() for u in os.environ.get('ADMIN_USERNAMES', '').split(',') if u.strip()}
# Client IDs de OAuth permitidos (web/android/ios), separados por coma. No son secretos.
GOOGLE_CLIENT_IDS = {c.strip() for c in os.environ.get('GOOGLE_CLIENT_IDS', '').split(',') if c.strip()}

db = SQLAlchemy(app)
bcrypt = Bcrypt(app)


def now():
    return datetime.now(timezone.utc)


# ----------------------------- Modelos -----------------------------

class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(120), unique=True, nullable=False)
    password = db.Column(db.String(60), nullable=True)  # hash bcrypt (nulo en cuentas Google)
    role = db.Column(db.String(10), nullable=False, default='user')
    google_sub = db.Column(db.String(64), unique=True, nullable=True)


class Note(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(120), nullable=False)
    content = db.Column(db.Text, nullable=False, default='')
    created_at = db.Column(db.DateTime, default=now)
    updated_at = db.Column(db.DateTime, default=now, onupdate=now)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)

    def to_dict(self):
        return {'id': self.id, 'title': self.title, 'content': self.content,
                'created_at': self.created_at.isoformat(),
                'updated_at': self.updated_at.isoformat()}


class SearchHistory(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False, index=True)
    term = db.Column('query', db.String(200), nullable=False)  # 'query' choca con Model.query
    # Identificador generado por el cliente: evita duplicados en reintentos.
    client_id = db.Column(db.String(64), nullable=False)
    searched_at = db.Column(db.DateTime, default=now)
    __table_args__ = (db.UniqueConstraint('user_id', 'client_id', name='uq_history_client'),)

    def to_dict(self):
        return {'id': self.id, 'query': self.term, 'client_id': self.client_id,
                'searched_at': self.searched_at.isoformat()}


class Favorite(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False, index=True)
    show_id = db.Column(db.Integer, nullable=False)  # id en TVMaze
    title = db.Column(db.String(200), nullable=False)
    image_url = db.Column(db.String(500), nullable=True)
    genres = db.Column(db.String(200), nullable=False, default='')  # separados por coma
    summary = db.Column(db.Text, nullable=True)
    updated_at = db.Column(db.DateTime, default=now, onupdate=now)
    __table_args__ = (db.UniqueConstraint('user_id', 'show_id', name='uq_fav_user_show'),)

    def to_dict(self):
        return {'show_id': self.show_id, 'title': self.title, 'image_url': self.image_url,
                'genres': self.genres, 'summary': self.summary,
                'updated_at': self.updated_at.isoformat()}


class SyncOp(db.Model):
    """Operaciones ya aplicadas (idempotencia de la cola offline)."""
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    op_id = db.Column(db.String(64), nullable=False)
    __table_args__ = (db.UniqueConstraint('user_id', 'op_id', name='uq_op'),)


# ----------------------------- Autenticacion -----------------------------

def generate_token(user):
    payload = {'user_id': user.id, 'role': user.role,
               'exp': now() + timedelta(minutes=app.config['JWT_EXP_MINUTES']), 'iat': now()}
    return jwt.encode(payload, app.config['JWT_SECRET_KEY'], algorithm='HS256')


def token_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        auth_header = request.headers.get('Authorization', '')
        if not auth_header.startswith('Bearer '):
            return jsonify({'message': 'Token faltante o mal formado'}), 401
        try:
            payload = jwt.decode(auth_header.split(' ', 1)[1], app.config['JWT_SECRET_KEY'],
                                 algorithms=['HS256'])
        except jwt.ExpiredSignatureError:
            return jsonify({'message': 'Token expirado'}), 401
        except jwt.InvalidTokenError:
            return jsonify({'message': 'Token invalido'}), 401
        current_user = db.session.get(User, payload['user_id'])
        if current_user is None:
            return jsonify({'message': 'Usuario no encontrado'}), 401
        return f(current_user, *args, **kwargs)
    return decorated


def admin_required(f):
    """El rol se lee de la BD (no del token) para que un cambio de rol sea inmediato."""
    @wraps(f)
    @token_required
    def decorated(current_user, *args, **kwargs):
        if current_user.role != 'admin':
            return jsonify({'message': 'Acceso denegado: se requiere rol administrador'}), 403
        return f(current_user, *args, **kwargs)
    return decorated


def session_response(user):
    return {'status': 'success', 'message': 'Login exitoso', 'token': generate_token(user),
            'user_id': user.id, 'username': user.username, 'role': user.role}


@app.route('/')
def hello():
    return jsonify({"message": "API Funcionando"})


@app.route('/register', methods=['POST'])
def register():
    data = request.get_json(silent=True) or {}
    username, password = data.get('username'), data.get('password')
    if not username or not password:
        return jsonify({"message": "username y password son requeridos"}), 400
    if User.query.filter_by(username=username).first():
        return jsonify({"message": "El usuario ya existe"}), 400
    hashed = bcrypt.generate_password_hash(password).decode('utf-8')
    role = 'admin' if username in ADMIN_USERNAMES else 'user'
    db.session.add(User(username=username, password=hashed, role=role))
    db.session.commit()
    return jsonify({"message": "Usuario creado exitosamente"}), 201


@app.route('/login', methods=['POST'])
def login():
    data = request.get_json(silent=True) or {}
    user = User.query.filter_by(username=data.get('username')).first()
    if user and user.password and data.get('password') and \
            bcrypt.check_password_hash(user.password, data['password']):
        return jsonify(session_response(user)), 200
    return jsonify({"status": "error", "message": "Credenciales invalidas"}), 401


def verify_google_id_token(id_token):
    """Valida el idToken con Google (tokeninfo) y comprueba audiencia y emisor."""
    resp = requests.get('https://oauth2.googleapis.com/tokeninfo',
                        params={'id_token': id_token}, timeout=10)
    if resp.status_code != 200:
        return None
    info = resp.json()
    if info.get('iss') not in ('accounts.google.com', 'https://accounts.google.com'):
        return None
    if not GOOGLE_CLIENT_IDS or info.get('aud') not in GOOGLE_CLIENT_IDS:
        return None
    if info.get('email_verified') not in (True, 'true'):
        return None
    return info


@app.route('/auth/google', methods=['POST'])
def auth_google():
    data = request.get_json(silent=True) or {}
    id_token = data.get('id_token')
    if not id_token:
        return jsonify({"message": "id_token es requerido"}), 400
    try:
        info = verify_google_id_token(id_token)
    except requests.RequestException:
        return jsonify({"message": "No se pudo contactar a Google"}), 502
    if info is None:
        return jsonify({"status": "error", "message": "Token de Google invalido"}), 401
    sub, email = info['sub'], info.get('email', info['sub'])
    user = User.query.filter_by(google_sub=sub).first()
    if user is None:
        username = email if not User.query.filter_by(username=email).first() else f'google:{sub}'
        user = User(username=username, google_sub=sub,
                    role='admin' if username in ADMIN_USERNAMES else 'user')
        db.session.add(user)
        db.session.commit()
    return jsonify(session_response(user)), 200


@app.route('/me', methods=['GET'])
@token_required
def me(current_user):
    return jsonify({'user_id': current_user.id, 'username': current_user.username,
                    'role': current_user.role}), 200


# ----------------------------- CRUD de notas (Practica 2) -----------------------------

@app.route('/notes', methods=['GET'])
@token_required
def list_notes(current_user):
    notes = Note.query.filter_by(user_id=current_user.id).order_by(Note.created_at.desc()).all()
    return jsonify([n.to_dict() for n in notes]), 200


@app.route('/notes', methods=['POST'])
@token_required
def create_note(current_user):
    data = request.get_json(silent=True) or {}
    if not data.get('title'):
        return jsonify({"message": "title es requerido"}), 400
    note = Note(title=data['title'], content=data.get('content', ''), user_id=current_user.id)
    db.session.add(note)
    db.session.commit()
    return jsonify(note.to_dict()), 201


@app.route('/notes/<int:note_id>', methods=['GET'])
@token_required
def get_note(current_user, note_id):
    note = Note.query.filter_by(id=note_id, user_id=current_user.id).first()
    if note is None:
        return jsonify({"message": "Nota no encontrada"}), 404
    return jsonify(note.to_dict()), 200


@app.route('/notes/<int:note_id>', methods=['PUT'])
@token_required
def update_note(current_user, note_id):
    note = Note.query.filter_by(id=note_id, user_id=current_user.id).first()
    if note is None:
        return jsonify({"message": "Nota no encontrada"}), 404
    data = request.get_json(silent=True) or {}
    if 'title' in data:
        if not data['title']:
            return jsonify({"message": "title no puede estar vacio"}), 400
        note.title = data['title']
    if 'content' in data:
        note.content = data['content']
    db.session.commit()
    return jsonify(note.to_dict()), 200


@app.route('/notes/<int:note_id>', methods=['DELETE'])
@token_required
def delete_note(current_user, note_id):
    note = Note.query.filter_by(id=note_id, user_id=current_user.id).first()
    if note is None:
        return jsonify({"message": "Nota no encontrada"}), 404
    db.session.delete(note)
    db.session.commit()
    return jsonify({"message": "Nota eliminada"}), 200


# ----------------------------- Historial y favoritos -----------------------------

def add_history(user_id, query, client_id):
    """Idempotente: el mismo client_id no se inserta dos veces."""
    if SearchHistory.query.filter_by(user_id=user_id, client_id=client_id).first():
        return False
    db.session.add(SearchHistory(user_id=user_id, term=query[:200], client_id=client_id))
    return True


def upsert_favorite(user_id, d):
    fav = Favorite.query.filter_by(user_id=user_id, show_id=d['show_id']).first()
    if fav is None:
        fav = Favorite(user_id=user_id, show_id=d['show_id'])
        db.session.add(fav)
    fav.title = (d.get('title') or '')[:200]
    fav.image_url = d.get('image_url')
    fav.genres = d.get('genres') or ''
    fav.summary = d.get('summary')


def remove_favorite(user_id, show_id):
    Favorite.query.filter_by(user_id=user_id, show_id=show_id).delete()


@app.route('/history', methods=['GET'])
@token_required
def get_history(current_user):
    rows = SearchHistory.query.filter_by(user_id=current_user.id) \
        .order_by(SearchHistory.searched_at.desc()).limit(200).all()
    return jsonify([r.to_dict() for r in rows]), 200


@app.route('/history', methods=['POST'])
@token_required
def post_history(current_user):
    data = request.get_json(silent=True) or {}
    if not data.get('query') or not data.get('client_id'):
        return jsonify({"message": "query y client_id son requeridos"}), 400
    created = add_history(current_user.id, data['query'], data['client_id'])
    db.session.commit()
    return jsonify({"created": created}), 201 if created else 200


@app.route('/history', methods=['DELETE'])
@token_required
def clear_history(current_user):
    SearchHistory.query.filter_by(user_id=current_user.id).delete()
    db.session.commit()
    return jsonify({"message": "Historial borrado"}), 200


@app.route('/favorites', methods=['GET'])
@token_required
def get_favorites(current_user):
    rows = Favorite.query.filter_by(user_id=current_user.id).order_by(Favorite.updated_at.desc()).all()
    return jsonify([r.to_dict() for r in rows]), 200


@app.route('/favorites/<int:show_id>', methods=['PUT'])
@token_required
def put_favorite(current_user, show_id):
    data = request.get_json(silent=True) or {}
    if not data.get('title'):
        return jsonify({"message": "title es requerido"}), 400
    data['show_id'] = show_id
    upsert_favorite(current_user.id, data)  # PUT es idempotente por naturaleza
    db.session.commit()
    return jsonify({"message": "Favorito guardado"}), 200


@app.route('/favorites/<int:show_id>', methods=['DELETE'])
@token_required
def delete_favorite(current_user, show_id):
    remove_favorite(current_user.id, show_id)
    db.session.commit()
    return jsonify({"message": "Favorito eliminado"}), 200


@app.route('/sync', methods=['POST'])
@token_required
def sync(current_user):
    """Aplica en lote la cola offline del cliente. Cada operacion lleva un op_id;
    si ya se aplico (reintento tras un corte de red) se ignora, evitando duplicados.

    Cuerpo: {"ops": [{"op_id","type":"add_history|add_favorite|remove_favorite","payload":{...}}]}
    Respuesta: {"applied": [op_id...], "skipped": [op_id...], "failed": [op_id...]}
    """
    data = request.get_json(silent=True) or {}
    ops = data.get('ops')
    if not isinstance(ops, list):
        return jsonify({"message": "ops debe ser una lista"}), 400
    applied, skipped, failed = [], [], []
    for op in ops:
        op_id, kind, p = op.get('op_id'), op.get('type'), op.get('payload') or {}
        if not op_id:
            continue
        if SyncOp.query.filter_by(user_id=current_user.id, op_id=op_id).first():
            skipped.append(op_id)
            continue
        try:
            if kind == 'add_history' and p.get('query'):
                add_history(current_user.id, p['query'], p.get('client_id') or op_id)
            elif kind == 'add_favorite' and p.get('show_id') and p.get('title'):
                upsert_favorite(current_user.id, p)
            elif kind == 'remove_favorite' and p.get('show_id'):
                remove_favorite(current_user.id, int(p['show_id']))
            else:
                failed.append(op_id)
                continue
            db.session.add(SyncOp(user_id=current_user.id, op_id=op_id))
            db.session.commit()
            applied.append(op_id)
        except Exception:  # noqa: BLE001 - una operacion mala no debe tumbar el lote
            app.logger.exception("sync op fallida")
            db.session.rollback()
            failed.append(op_id)
    return jsonify({"applied": applied, "skipped": skipped, "failed": failed}), 200


# ----------------------------- Administrador -----------------------------

@app.route('/admin/users', methods=['GET'])
@admin_required
def admin_users(current_user):
    return jsonify([{'id': u.id, 'username': u.username, 'role': u.role}
                    for u in User.query.order_by(User.id).all()]), 200


@app.route('/admin/users/<int:user_id>/history', methods=['GET'])
@admin_required
def admin_user_history(current_user, user_id):
    rows = SearchHistory.query.filter_by(user_id=user_id) \
        .order_by(SearchHistory.searched_at.desc()).limit(200).all()
    return jsonify([r.to_dict() for r in rows]), 200


@app.route('/admin/users/<int:user_id>/favorites', methods=['GET'])
@admin_required
def admin_user_favorites(current_user, user_id):
    rows = Favorite.query.filter_by(user_id=user_id).order_by(Favorite.updated_at.desc()).all()
    return jsonify([r.to_dict() for r in rows]), 200


with app.app_context():
    db.create_all()

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
