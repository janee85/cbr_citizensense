import os, base64, hashlib, hmac, json, secrets, time
from datetime import datetime, timedelta, timezone
from typing import Optional

from dotenv import load_dotenv
from fastapi import FastAPI, Depends, HTTPException, Request
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, EmailStr, Field
from sqlalchemy import create_engine, String, Integer, DateTime, Text, Boolean, Float, select, func
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, sessionmaker, Session

load_dotenv()
DATABASE_URL = os.getenv('DATABASE_URL', '').strip()
JWT_SECRET = os.getenv('JWT_SECRET', '').strip()
if not DATABASE_URL:
    raise RuntimeError('DATABASE_URL is missing. Copy .env.example to .env and configure PostgreSQL.')
if not JWT_SECRET:
    raise RuntimeError('JWT_SECRET is missing. Set a long random secret in backend/.env.')

engine = create_engine(DATABASE_URL, pool_pre_ping=True)
SessionLocal = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)

class Base(DeclarativeBase): pass

# These app-specific tables are deliberately namespaced so we do not overwrite
# existing school/project tables whose schema has not yet been inspected.
class User(Base):
    __tablename__ = 'citizensense_users'
    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    name: Mapped[str] = mapped_column(String(160))
    email: Mapped[str] = mapped_column(String(254), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(256))
    role: Mapped[str] = mapped_column(String(20), default='citizen')
    office_id: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

class ComplaintRow(Base):
    __tablename__ = 'citizensense_complaints'
    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    citizen_id: Mapped[int] = mapped_column(Integer, index=True)
    title: Mapped[str] = mapped_column(String(200))
    description: Mapped[str] = mapped_column(Text)
    category_id: Mapped[int] = mapped_column(Integer)
    office_id: Mapped[int] = mapped_column(Integer)
    location_id: Mapped[int] = mapped_column(Integer)
    status: Mapped[str] = mapped_column(String(30), default='submitted')
    priority: Mapped[str] = mapped_column(String(20), default='medium')
    sentiment: Mapped[str] = mapped_column(String(20), default='neutral')
    confidence: Mapped[float] = mapped_column(Float, default=0.0)
    attachment_name: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    response_message: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), index=True)

Base.metadata.create_all(bind=engine)
app = FastAPI(title='CBR CitizenSense API', version='0.1.0')
# api port(3000, 5000, 8000,...)
app.add_middleware(CORSMiddleware, allow_origins=['http://localhost:3000','http://localhost:5000','http://localhost:8000','http://127.0.0.1:3000','http://127.0.0.1:5000','http://127.0.0.1:8000','http://localhost:54321'], allow_credentials=True, allow_methods=['*'], allow_headers=['*'])

@app.exception_handler(HTTPException)
async def api_error_handler(request: Request, exc: HTTPException):
    detail = exc.detail if isinstance(exc.detail, dict) else {'code': 'REQUEST_ERROR', 'message': str(exc.detail), 'details': {}}
    return JSONResponse(status_code=exc.status_code, content={'error': {'code': detail.get('code', 'REQUEST_ERROR'), 'message': detail.get('message', 'Request failed.'), 'details': detail.get('details', {})}})

def get_db():
    db = SessionLocal()
    try: yield db
    finally: db.close()

def ok(data): return {'data': data}
def fail(status, code, message, details=None):
    raise HTTPException(status_code=status, detail={'code': code, 'message': message, 'details': details or {}})

def hash_password(password: str) -> str:
    salt = secrets.token_bytes(16)
    digest = hashlib.pbkdf2_hmac('sha256', password.encode(), salt, 310000)
    return base64.b64encode(salt + digest).decode()
def verify_password(password: str, stored: str) -> bool:
    try:
        raw = base64.b64decode(stored.encode()); salt, digest = raw[:16], raw[16:]
        return hmac.compare_digest(hashlib.pbkdf2_hmac('sha256', password.encode(), salt, 310000), digest)
    except Exception: return False

def b64(data: bytes) -> str: return base64.urlsafe_b64encode(data).rstrip(b'=').decode()
def make_token(user: User) -> str:
    now=int(time.time()); head=b64(json.dumps({'alg':'HS256','typ':'JWT'},separators=(',',':')).encode())
    payload=b64(json.dumps({'sub':user.id,'role':user.role,'iat':now,'exp':now+60*60*8},separators=(',',':')).encode())
    message=f'{head}.{payload}'
    sig=b64(hmac.new(JWT_SECRET.encode(),message.encode(),hashlib.sha256).digest())
    return f'{message}.{sig}'
def decode_token(token: str):
    try:
        head,payload,sig=token.split('.'); message=f'{head}.{payload}'
        expected=b64(hmac.new(JWT_SECRET.encode(),message.encode(),hashlib.sha256).digest())
        if not hmac.compare_digest(sig,expected): raise ValueError()
        data=json.loads(base64.urlsafe_b64decode(payload+'='*((4-len(payload)%4)%4)))
        if int(data['exp']) < int(time.time()): raise ValueError()
        return data
    except Exception: raise HTTPException(401, detail={'code':'INVALID_TOKEN','message':'Session expired or invalid.','details':{}})

security = HTTPBearer(auto_error=False)

def current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
    db: Session = Depends(get_db)
) -> User:
    if not credentials:
        raise HTTPException(
            401,
            detail={
                'code': 'UNAUTHORIZED',
                'message': 'Please log in.',
                'details': {}
            }
        )

    payload = decode_token(credentials.credentials)
    user = db.get(User, int(payload['sub']))

    if not user or not user.active:
        raise HTTPException(
            401,
            detail={
                'code': 'UNAUTHORIZED',
                'message': 'Account unavailable.',
                'details': {}
            }
        )

    return user
def require_role(user: User, *roles):
    if user.role not in roles: raise HTTPException(403, detail={'code':'FORBIDDEN','message':'You are not authorized for this action.','details':{}})

def user_json(u): return {'id':u.id,'name':u.name,'email':u.email,'role':u.role,'office_id':u.office_id,'active':u.active}
def iso(dt): return (dt or datetime.now(timezone.utc)).isoformat()
def complaint_json(c: ComplaintRow, db: Session):
    u=db.get(User,c.citizen_id)
    return {'id':c.id,'title':c.title,'description':c.description,'category_id':c.category_id,'office_id':c.office_id,'location_id':c.location_id,'status':c.status,'priority':c.priority,'sentiment':c.sentiment,'created_at':iso(c.created_at),'citizen_name':u.name if u else '','citizen_email':u.email if u else '', 'attachment_name':c.attachment_name}

class RegisterIn(BaseModel):
    name: str = Field(min_length=2,max_length=160)
    email: EmailStr
    password: str = Field(min_length=8,max_length=128)
    office_id: Optional[int] = None
class LoginIn(BaseModel): email: EmailStr; password: str
class ComplaintIn(BaseModel):
    title: str = Field(min_length=3,max_length=200)
    description: str = Field(min_length=10,max_length=10000)
    category_id: int = Field(ge=1)
    office_id: int = Field(ge=1)
    location_id: int = Field(ge=1)
class ClassifyIn(BaseModel): category_id: int; description: str
class StatusIn(BaseModel): status: str; response_message: Optional[str]=None
class ChangePasswordIn(BaseModel): current_password: str; new_password: str = Field(min_length=8,max_length=128)

@app.get('/')
def home(): return {'message':'CBR CitizenSense API is running','docs':'/docs'}
@app.get('/health')
def health_check():
    return {'status': 'ok'}
@app.get('/api/health/db')
def health(db: Session=Depends(get_db)):
    db.execute(select(1)); return {'database':'connected'}

@app.post('/api/auth/register')
def register(data: RegisterIn, db: Session=Depends(get_db)):
    email=str(data.email).lower().strip()
    if db.scalar(select(User).where(User.email==email)):
        raise HTTPException(409,detail={'code':'EMAIL_EXISTS','message':'An account with this email already exists.','details':{}})
    # Prototype compatibility with current UI. Production staff/admin roles must be granted by an administrator.
    role='admin' if email.endswith('@admin.com') else 'staff' if email.endswith('@staff.com') else 'citizen'
    user=User(name=data.name.strip(),email=email,password_hash=hash_password(data.password),role=role,office_id=data.office_id if role=='staff' else None,active=True)
    db.add(user); db.commit(); db.refresh(user)
    return ok({'id':user.id,'message':'Registration successful.'})

@app.post('/api/auth/login')
def login(data: LoginIn, db: Session=Depends(get_db)):
    user=db.scalar(select(User).where(User.email==str(data.email).lower().strip()))
    if not user or not verify_password(data.password,user.password_hash) or not user.active:
        raise HTTPException(401,detail={'code':'INVALID_CREDENTIALS','message':'Email or password is incorrect.','details':{}})
    return ok({'user':user_json(user),'token':make_token(user)})

@app.post('/api/auth/change-password')
def change_password(data: ChangePasswordIn, user: User=Depends(current_user), db: Session=Depends(get_db)):
    if not verify_password(data.current_password,user.password_hash):
        raise HTTPException(400,detail={'code':'PASSWORD_MISMATCH','message':'Current password is incorrect.','details':{}})
    user.password_hash=hash_password(data.new_password); db.commit(); return ok({'message':'Password updated.'})

@app.post('/api/complaints/classify')
def classify(data: ClassifyIn, user: User=Depends(current_user)):
    # Temporary rule-based preview only; this is NOT a trained ML model.
    t=data.description.lower()
    critical_words=['life-threatening','trapped','collapsed','severe injury','fire spreading']
    high_words=['flood','exposed wire','no electricity','accident','injury','dangerous','overflow']
    medium_words=['broken','damaged','not working','garbage','noise','leak']
    priority='critical' if any(w in t for w in critical_words) else 'high' if any(w in t for w in high_words) else 'medium' if any(w in t for w in medium_words) else 'low'
    sentiment='negative' if any(w in t for w in high_words+medium_words+critical_words) else 'neutral'
    return ok({'category':str(data.category_id),'sentiment':sentiment,'priority':priority,'confidence':0.0,'office_id':None,'keywords':[],'category_only':True})

@app.post('/api/complaints')
def create_complaint(data: ComplaintIn, user: User=Depends(current_user), db: Session=Depends(get_db)):
    require_role(user,'citizen')
    classification=classify(ClassifyIn(category_id=data.category_id,description=data.description),user)
    c=ComplaintRow(citizen_id=user.id,title=data.title.strip(),description=data.description.strip(),category_id=data.category_id,office_id=data.office_id,location_id=data.location_id,status='submitted',priority=classification['data']['priority'],sentiment=classification['data']['sentiment'],confidence=0.0)
    db.add(c); db.commit(); db.refresh(c)
    return ok(complaint_json(c,db))

@app.get('/api/complaints')
def list_own(user: User=Depends(current_user), db: Session=Depends(get_db)):
    rows=list(db.scalars(select(ComplaintRow).where(ComplaintRow.citizen_id==user.id).order_by(ComplaintRow.created_at.desc())))
    return ok({'items':[complaint_json(c,db) for c in rows]})
@app.get('/api/staff/complaints')
def list_staff(user: User=Depends(current_user), db: Session=Depends(get_db)):
    require_role(user,'staff'); rows=list(db.scalars(select(ComplaintRow).where(ComplaintRow.office_id==user.office_id).order_by(ComplaintRow.created_at.desc())))
    return ok({'items':[complaint_json(c,db) for c in rows]})
@app.get('/api/admin/complaints')
def list_all(user: User=Depends(current_user), db: Session=Depends(get_db)):
    require_role(user,'admin'); rows=list(db.scalars(select(ComplaintRow).order_by(ComplaintRow.created_at.desc())))
    return ok({'items':[complaint_json(c,db) for c in rows]})
@app.get('/api/complaints/{complaint_id}')
def complaint_detail(complaint_id: int, user: User=Depends(current_user), db: Session=Depends(get_db)):
    c=db.get(ComplaintRow,complaint_id)
    if not c: raise HTTPException(404,detail={'code':'NOT_FOUND','message':'Complaint not found.','details':{}})
    if user.role=='citizen' and c.citizen_id!=user.id: raise HTTPException(403,detail={'code':'FORBIDDEN','message':'Not your complaint.','details':{}})
    if user.role=='staff' and c.office_id!=user.office_id: raise HTTPException(403,detail={'code':'FORBIDDEN','message':'Not assigned to your office.','details':{}})
    return ok({**complaint_json(c,db),'location':str(c.location_id),'confidence':c.confidence,'keywords':[],'responses':([{'message':c.response_message,'staff_name':user.name,'created_at':iso(c.created_at)}] if c.response_message else []),'history':[{'status':'submitted','note':'Complaint submitted.','by':complaint_json(c,db)['citizen_name'],'at':iso(c.created_at)}]})
@app.patch('/api/complaints/{complaint_id}/status')
def update_status(complaint_id: int, data: StatusIn, user: User=Depends(current_user), db: Session=Depends(get_db)):
    require_role(user,'staff'); c=db.get(ComplaintRow,complaint_id)
    if not c: raise HTTPException(404,detail={'code':'NOT_FOUND','message':'Complaint not found.','details':{}})
    if c.office_id!=user.office_id: raise HTTPException(403,detail={'code':'FORBIDDEN','message':'Complaint belongs to another office.','details':{}})
    legal={'submitted':['received','in_progress'],'received':['in_progress','resolved'],'in_progress':['resolved'],'resolved':['closed','in_progress'],'closed':[]}
    if data.status not in legal.get(c.status,[]): raise HTTPException(409,detail={'code':'INVALID_TRANSITION','message':'This status change is not allowed.','details':{}})
    c.status=data.status; c.response_message=(data.response_message or '').strip() or None; db.commit(); return ok({'message':'Status updated.'})

@app.get('/api/dashboard/summary')
def dashboard(user: User=Depends(current_user), db: Session=Depends(get_db)):
    q=select(ComplaintRow)
    if user.role=='citizen': q=q.where(ComplaintRow.citizen_id==user.id)
    elif user.role=='staff': q=q.where(ComplaintRow.office_id==user.office_id)
    rows=list(db.scalars(q.order_by(ComplaintRow.created_at.desc())))
    pending=sum(c.status in ('submitted','received') for c in rows); progress=sum(c.status=='in_progress' for c in rows); solved=sum(c.status in ('resolved','closed') for c in rows)
    cats={}
    for c in rows: cats[c.category_id]=cats.get(c.category_id,0)+1
    total=len(rows)
    return ok({'pending':pending,'in_progress':progress,'solved':solved,'pending_delta':0,'in_progress_delta':0,'solved_delta':0,'service_level':round(solved*100/total,1) if total else 0,'service_target':75,'feedback_rating':0,'chart':{'labels':[],'pending':[],'in_progress':[]},'recent':[complaint_json(c,db) for c in rows[:5]],'categories':[{'name':f'Category {k}','percent':round(v*100/total) if total else 0} for k,v in sorted(cats.items(),key=lambda x:-x[1])[:4]]})

@app.get('/api/reports')
def reports(days: int=30, office_id: Optional[int]=None, category_id: Optional[int]=None, user: User=Depends(current_user), db: Session=Depends(get_db)):
    require_role(user,'admin'); q=select(ComplaintRow)
    if days>0: q=q.where(ComplaintRow.created_at >= datetime.now(timezone.utc)-timedelta(days=days))
    if office_id is not None: q=q.where(ComplaintRow.office_id==office_id)
    if category_id is not None: q=q.where(ComplaintRow.category_id==category_id)
    rows=list(db.scalars(q.order_by(ComplaintRow.created_at.desc())))
    def tally(fn):
        d={}
        for c in rows:
            label=fn(c); d[label]=d.get(label,0)+1
        return [{'label':k,'count':v} for k,v in sorted(d.items())]
    closed=sum(c.status in ('resolved','closed') for c in rows)
    return ok({'total':len(rows),'open':len(rows)-closed,'resolved':closed,'by_category':tally(lambda c:f'Category {c.category_id}'),'by_office':tally(lambda c:f'Office {c.office_id}'),'by_priority':tally(lambda c:c.priority),'by_status':tally(lambda c:c.status),'rows':[complaint_json(c,db) for c in rows]})

@app.get('/api/admin/users')
def admin_users(user: User=Depends(current_user), db: Session=Depends(get_db)):
    require_role(user,'admin'); return ok({'items':[user_json(u) for u in db.scalars(select(User).order_by(User.name))]})
@app.patch('/api/admin/users/{user_id}')
def set_active(user_id: int, active: bool, user: User=Depends(current_user), db: Session=Depends(get_db)):
    require_role(user,'admin'); target=db.get(User,user_id)
    if not target: raise HTTPException(404,detail={'code':'NOT_FOUND','message':'User not found.','details':{}})
    if target.id==user.id: raise HTTPException(409,detail={'code':'CONFLICT','message':'You cannot deactivate your own account.','details':{}})
    target.active=active; db.commit(); return ok({'message':'User updated.'})

@app.get('/api/admin/offices')
def admin_offices(user: User=Depends(current_user), db: Session=Depends(get_db)):
    require_role(user,'admin')
    names={1:'City Engineering Office',2:'City Health Office',3:'City Environment and Natural Resources Office',4:'City Social Welfare and Development Office',5:'City Disaster Risk Reduction and Management Office',6:'City Public Safety Office',7:"City Mayor's Office (General Concerns)"}
    items=[]
    for oid,name in names.items():
        total=db.scalar(select(func.count()).select_from(ComplaintRow).where(ComplaintRow.office_id==oid)) or 0
        opened=db.scalar(select(func.count()).select_from(ComplaintRow).where(ComplaintRow.office_id==oid,ComplaintRow.status.notin_(['resolved','closed']))) or 0
        staff=db.scalar(select(func.count()).select_from(User).where(User.office_id==oid,User.role=='staff')) or 0
        items.append({'id':oid,'name':name,'staff_count':staff,'open_count':opened,'total_count':total})
    return ok({'items':items})
@app.get('/api/notifications')
def notifications(user: User=Depends(current_user), db: Session=Depends(get_db)):
    return ok({'items':[]})
