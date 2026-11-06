import os, sys
os.environ.setdefault('JWT_SECRET_KEY', 'test')
os.environ['DATABASE_URL'] = 'sqlite://'
os.environ['ADMIN_USERNAMES'] = 'admin'
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
import app as a


def client():
    return a.app.test_client()


def auth(c, u, p='pw'):
    c.post('/register', json={'username': u, 'password': p})
    t = c.post('/login', json={'username': u, 'password': p}).get_json()['token']
    return {'Authorization': f'Bearer {t}'}


def test_favorites_and_isolation():
    c = client()
    h1, h2 = auth(c, 'ana'), auth(c, 'beto')
    body = {'title': 'Show', 'genres': 'Drama'}
    assert c.put('/favorites/1', json=body, headers=h1).status_code == 200
    assert c.put('/favorites/1', json=body, headers=h1).status_code == 200  # idempotente
    assert len(c.get('/favorites', headers=h1).get_json()) == 1
    assert c.get('/favorites', headers=h2).get_json() == []


def test_sync_idempotent():
    c = client()
    h = auth(c, 'carla')
    ops = [{'op_id': 'o1', 'type': 'add_favorite', 'payload': {'show_id': 5, 'title': 'X'}},
           {'op_id': 'o2', 'type': 'add_history', 'payload': {'query': 'lost', 'client_id': 'c1'}}]
    r1 = c.post('/sync', json={'ops': ops}, headers=h).get_json()
    r2 = c.post('/sync', json={'ops': ops}, headers=h).get_json()
    assert r1['applied'] == ['o1', 'o2'] and r2['skipped'] == ['o1', 'o2']
    assert len(c.get('/history', headers=h).get_json()) == 1


def test_admin_forbidden_and_allowed():
    c = client()
    hu, ha = auth(c, 'dani'), auth(c, 'admin')
    assert c.get('/admin/users', headers=hu).status_code == 403
    assert c.get('/admin/users', headers=ha).status_code == 200
    assert c.get('/admin/users/1/favorites', headers=hu).status_code == 403


def test_google_invalid_token():
    c = client()
    assert c.post('/auth/google', json={}).status_code == 400
