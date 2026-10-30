import logging
import uuid
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, HTTPException, Response
from sqlalchemy import select, text
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session
from starlette.requests import Request

from app import models
from app.database import Base, engine, get_db
from app.logging_config import configure_logging
from app.schemas import TaskCreate, TaskOut, TaskUpdate

configure_logging()
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Suitable for this assessment; use schema migrations in a larger system.
    Base.metadata.create_all(bind=engine)
    yield
    engine.dispose()


app = FastAPI(title="Apex Operations API", version="1.2.0", lifespan=lifespan)


@app.middleware("http")
async def request_logging(request: Request, call_next):
    request_id = request.headers.get("X-Request-ID") or str(uuid.uuid4())
    response = await call_next(request)
    response.headers["X-Request-ID"] = request_id
    logger.info(
        "%s %s", request.method, request.url.path,
        extra={"request_id": request_id, "status_code": response.status_code},
    )
    return response


@app.get("/")
def root():
    return {"service": "apex-operations-api", "version": app.version}


@app.get("/health")
def health():
    return {"status": "alive"}


@app.get("/ready")
def ready(response: Response):
    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
    except SQLAlchemyError:
        logger.warning("database_readiness_check_failed")
        response.status_code = 503
        return {"status": "not_ready", "database": "unavailable"}
    return {"status": "ready", "database": "connected"}


@app.post("/api/tasks", response_model=TaskOut, status_code=201)
def create_task(task: TaskCreate, db: Session = Depends(get_db)):
    row = models.Task(title=task.title, status="pending")
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


@app.get("/api/tasks", response_model=list[TaskOut])
def list_tasks(db: Session = Depends(get_db)):
    return db.scalars(select(models.Task).order_by(models.Task.id)).all()


@app.get("/api/tasks/{task_id}", response_model=TaskOut)
def get_task(task_id: int, db: Session = Depends(get_db)):
    row = db.get(models.Task, task_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Task not found")
    return row


@app.patch("/api/tasks/{task_id}", response_model=TaskOut)
def update_task(task_id: int, task: TaskUpdate, db: Session = Depends(get_db)):
    row = db.get(models.Task, task_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Task not found")
    row.status = task.status
    db.commit()
    db.refresh(row)
    return row
