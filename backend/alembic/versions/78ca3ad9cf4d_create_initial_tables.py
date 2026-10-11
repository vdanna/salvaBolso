"""create initial tables

Revision ID: 78ca3ad9cf4d
Revises:
Create Date: 2026-07-17
"""

from alembic import op

from app.db.base import Base
from app.db import models  # noqa: F401


revision = "78ca3ad9cf4d"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    Base.metadata.create_all(bind=bind)


def downgrade() -> None:
    bind = op.get_bind()
    Base.metadata.drop_all(bind=bind)
