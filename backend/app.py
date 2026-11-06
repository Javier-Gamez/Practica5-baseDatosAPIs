from datetime import datetime, timedelta, timezone
from functools import wraps
import os

import jwt
from flask import Flask, jsonify, request
from flask_bcrypt import Bcrypt
from flask_sqlalchemy import SQLAlchemy

app = Flask(__name__)

# 1. Configuracion de la base de datos (Postgres, ver docker-compose.yml)
app.config['SQLALCHEMY_DATABASE_URI'] = os.environ.get(
    'DATABASE_URL', 'sqlite:///site.db'
)
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

# 2. Configuracion de JWT (sesiones seguras)
app.config['JWT_SECRET_KEY'] = os.environ['JWT_SECRET_KEY']
app.config['JWT_EXP_MINUTES'] = int(os.environ.get('JWT_EXP_MINUTES', '60'))

db = SQLAlchemy(app)
bcrypt = Bcrypt(app)


# 3. Modelos

class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(20), unique=True, nullable=False)
    password = db.Column(db.String(60), nullable=False)  # hash de bcrypt

    def __repr__(self):
        return f"User('{self.username}')"


class Note(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(120), nullable=False)
    content = db.Column(db.Text, nullable=False, default='')
    created_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc))
    updated_at = db.Column(
        db.DateTime,
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)

    def to_dict(self):
        return {
            'id': self.id,
            'title': self.title,
            'content': self.content,
            'created_at': self.created_at.isoformat(),
            'updated_at': self.updated_at.isoformat(),
        }


# 4. Utilidades de autenticacion

def generate_token(user_id):
    payload = {
        'user_id': user_id,
        'exp': datetime.now(timezone.utc) + timedelta(minutes=app.config['JWT_EXP_MINUTES']),
        'iat': datetime.now(timezone.utc),
    }
    return jwt.encode(payload, app.config['JWT_SECRET_KEY'], algorithm='HS256')


def token_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        auth_header = request.headers.get('Authorization', '')
        if not auth_header.startswith('Bearer '):
            return jsonify({'message': 'Token faltante o mal formado'}), 401

        token = auth_header.split(' ', 1)[1]
        try:
            payload = jwt.decode(token, app.config['JWT_SECRET_KEY'], algorithms=['HS256'])
        except jwt.ExpiredSignatureError:
            return jsonify({'message': 'Token expirado'}), 401
        except jwt.InvalidTokenError:
            return jsonify({'message': 'Token invalido'}), 401

        current_user = db.session.get(User, payload['user_id'])
        if current_user is None:
            return jsonify({'message': 'Usuario no encontrado'}), 401

        return f(current_user, *args, **kwargs)

    return decorated


# 5. Rutas de verificacion y autenticacion

@app.route('/')
def hello():
    return jsonify({"message": "API Funcionando"})


@app.route('/register', methods=['POST'])
def register():
    data = request.get_json(silent=True) or {}
    username = data.get('username')
    password = data.get('password')

    if not username or not password:
        return jsonify({"message": "username y password son requeridos"}), 400

    if User.query.filter_by(username=username).first():
        return jsonify({"message": "El usuario ya existe"}), 400

    hashed_password = bcrypt.generate_password_hash(password).decode('utf-8')

    new_user = User(username=username, password=hashed_password)
    db.session.add(new_user)
    db.session.commit()

    return jsonify({"message": "Usuario creado exitosamente"}), 201


@app.route('/login', methods=['POST'])
def login():
    data = request.get_json(silent=True) or {}
    username = data.get('username')
    password = data.get('password')

    user = User.query.filter_by(username=username).first()

    if user and bcrypt.check_password_hash(user.password, password):
        token = generate_token(user.id)
        return jsonify({
            "status": "success",
            "message": "Login exitoso",
            "token": token,
            "user_id": user.id,
            "username": user.username
        }), 200

    return jsonify({"status": "error", "message": "Credenciales invalidas"}), 401


# 6. Rutas CRUD de Notas (protegidas)

@app.route('/notes', methods=['GET'])
@token_required
def list_notes(current_user):
    notes = Note.query.filter_by(user_id=current_user.id).order_by(Note.created_at.desc()).all()
    return jsonify([note.to_dict() for note in notes]), 200


@app.route('/notes', methods=['POST'])
@token_required
def create_note(current_user):
    data = request.get_json(silent=True) or {}
    title = data.get('title')
    content = data.get('content', '')

    if not title:
        return jsonify({"message": "title es requerido"}), 400

    note = Note(title=title, content=content, user_id=current_user.id)
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


if __name__ == '__main__':
    with app.app_context():
        db.create_all()

    app.run(host='0.0.0.0', port=5000, debug=True)
