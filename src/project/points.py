"""قيم النقاط الخضراء وطريقة منحها. القيم أمثلة أولية قابلة للتعديل من هنا."""
from datetime import date

from sqlalchemy.orm import Session

from project.models import PointEntryDB, TreeDB, TreeUpdateDB

TREES_PER_REWARD = 3
POINTS_PER_REWARD = 2
CAMPAIGN_POINTS = 5
SURVIVAL_POINTS = 3
SURVIVAL_DAYS = 365
UPDATE_POINTS = 1
UPDATE_INTERVAL_DAYS = 30
REPORT_POINTS = 1
REDEEM_POINTS = 50


def rules() -> dict:
    return {
        "trees_per_reward": TREES_PER_REWARD,
        "points_per_reward": POINTS_PER_REWARD,
        "campaign_points": CAMPAIGN_POINTS,
        "survival_points": SURVIVAL_POINTS,
        "update_points": UPDATE_POINTS,
        "update_interval_days": UPDATE_INTERVAL_DAYS,
        "report_points": REPORT_POINTS,
        "redeem_points": REDEEM_POINTS,
    }


def award(db: Session, user_id: int, points: int, reason: str, source: str) -> None:
    """يضيف حركة نقاط مرة واحدة لكل مصدر. الحفظ على من يستدعيها."""
    db.flush()
    if db.query(PointEntryDB).filter(PointEntryDB.source == source).first() is None:
        db.add(PointEntryDB(user_id=user_id, points=points, reason=reason, source=source))


def balance(db: Session, user_id: int) -> int:
    db.flush()
    entries = db.query(PointEntryDB.points).filter(PointEntryDB.user_id == user_id).all()
    return sum(points for (points,) in entries)


def award_tree_groups(db: Session, user_id: int) -> None:
    """يمنح نقاط كل مجموعة كاملة من الأشجار المعتمدة للمستخدم."""
    db.flush()
    approved = db.query(TreeDB).filter(TreeDB.user_id == user_id, TreeDB.review_status == "approved").count()
    for group in range(1, approved // TREES_PER_REWARD + 1):
        award(db, user_id, POINTS_PER_REWARD, f"زراعة {TREES_PER_REWARD} أشجار معتمدة", f"trees:{user_id}:{group}")


def award_update(db: Session, tree: TreeDB, update: TreeUpdateDB, today: date | None = None) -> None:
    """نقاط متابعة معتمدة، وإن كانت الشجرة حية بعد سنة فنقاط بقائها مرة واحدة."""
    award(db, tree.user_id, UPDATE_POINTS, f"متابعة نمو شجرة {tree.name}", f"update:{update.id}")
    # العمر من تاريخ التسجيل لا تاريخ الزراعة، لأن المستخدم هو من يدخل تاريخ الزراعة
    registered_days = ((today or date.today()) - tree.created_at.date()).days
    if update.status != "dead" and registered_days >= SURVIVAL_DAYS:
        award(db, tree.user_id, SURVIVAL_POINTS, f"بقاء شجرة {tree.name} حية بعد سنة", f"survival:{tree.id}")
