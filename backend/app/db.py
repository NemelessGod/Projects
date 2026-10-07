import os

from sqlalchemy import create_engine

DEFAULT_URL = "postgresql+psycopg://postgres@127.0.0.1:55432/spin_kingdom"
engine = create_engine(os.getenv("DATABASE_URL", DEFAULT_URL), pool_pre_ping=True)
