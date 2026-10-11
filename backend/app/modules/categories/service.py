from typing import Any

from sqlalchemy import func, or_
from sqlalchemy.orm import Session

from app.db.models import Category, CategoryRule, Transaction


DEFAULT_CATEGORIES = [
    ("Renda", "#e99537", "circle-dollar-sign", "income"),
    ("Pagamentos de Empréstimos", "#6471eb", "credit-card", "expense"),
    ("Taxas", "#6471eb", "credit-card", "expense"),
    ("Entretenimento", "#df4e92", "drama", "expense"),
    ("Alimentação", "#eb5429", "utensils", "expense"),
    ("Compras", "#e99537", "shopping-cart", "expense"),
    ("Casa e Reparos", "#6471eb", "house", "expense"),
    ("Saúde", "#4da568", "pill", "expense"),
    ("Cuidados Pessoais", "#4da568", "pill", "expense"),
    ("Serviços", "#4da568", "briefcase", "expense"),
    ("Presentes e Doações", "#61c9ea", "hand-helping", "expense"),
    ("Transporte", "#df4e92", "bus", "expense"),
    ("Viagem", "#df4e92", "plane", "expense"),
    ("Moradia e Contas", "#db5a54", "lightbulb", "expense"),
]


DEFAULT_RULES = [
    ("Renda", "salario", "contains", "description", 10),
    ("Renda", "salário", "contains", "description", 10),
    ("Renda", "pagamento recebido", "contains", "description", 20),
    ("Alimentação", "ifood", "contains", "description", 10),
    ("Alimentação", "mercado", "contains", "description", 20),
    ("Alimentação", "supermercado", "contains", "description", 20),
    ("Alimentação", "padaria", "contains", "description", 20),
    ("Alimentação", "restaurante", "contains", "description", 20),
    ("Transporte", "uber", "contains", "description", 10),
    ("Transporte", "99", "contains", "description", 20),
    ("Transporte", "posto", "contains", "description", 20),
    ("Transporte", "combustivel", "contains", "description", 20),
    ("Transporte", "combustível", "contains", "description", 20),
    ("Saúde", "drogaria", "contains", "description", 10),
    ("Saúde", "farmacia", "contains", "description", 10),
    ("Saúde", "farmácia", "contains", "description", 10),
    ("Saúde", "hospital", "contains", "description", 20),
    ("Moradia e Contas", "energia", "contains", "description", 10),
    ("Moradia e Contas", "sabesp", "contains", "description", 10),
    ("Moradia e Contas", "enel", "contains", "description", 10),
    ("Moradia e Contas", "aluguel", "contains", "description", 10),
    ("Serviços", "netflix", "contains", "description", 20),
    ("Serviços", "spotify", "contains", "description", 20),
    ("Serviços", "google", "contains", "description", 30),
    ("Serviços", "apple", "contains", "description", 30),
    ("Compras", "amazon", "contains", "description", 20),
    ("Compras", "mercadolivre", "contains", "description", 20),
    ("Compras", "shopee", "contains", "description", 20),
]


def bootstrap_default_categories(
    db: Session,
    user_id: int,
) -> list[Category]:
    created_or_found: list[Category] = []

    for name, color, icon, classification in DEFAULT_CATEGORIES:
        category = (
            db.query(Category)
            .filter(
                Category.user_id == user_id,
                func.lower(Category.name) == name.lower(),
            )
            .first()
        )

        if category is None:
            category = Category(
                user_id=user_id,
                name=name,
                color=color,
                lucide_icon=icon,
                classification=classification,
            )

            db.add(category)
            db.flush()

        created_or_found.append(category)

    db.commit()

    return created_or_found


def bootstrap_default_rules(
    db: Session,
    user_id: int,
) -> list[CategoryRule]:
    bootstrap_default_categories(db=db, user_id=user_id)

    created_or_found: list[CategoryRule] = []

    for category_name, pattern, match_type, field, priority in DEFAULT_RULES:
        category = (
            db.query(Category)
            .filter(
                Category.user_id == user_id,
                func.lower(Category.name) == category_name.lower(),
            )
            .first()
        )

        if category is None:
            continue

        existing_rule = (
            db.query(CategoryRule)
            .filter(
                CategoryRule.user_id == user_id,
                CategoryRule.category_id == category.id,
                func.lower(CategoryRule.pattern) == pattern.lower(),
                CategoryRule.field == field,
            )
            .first()
        )

        if existing_rule is None:
            existing_rule = CategoryRule(
                user_id=user_id,
                category_id=category.id,
                pattern=pattern,
                match_type=match_type,
                field=field,
                priority=priority,
                is_active=True,
            )

            db.add(existing_rule)
            db.flush()

        created_or_found.append(existing_rule)

    db.commit()

    return created_or_found


def validate_category_parent(
    db: Session,
    user_id: int,
    parent_id: int | None,
    classification: str,
) -> Category | None:
    if parent_id is None:
        return None

    parent = (
        db.query(Category)
        .filter(
            Category.id == parent_id,
            Category.user_id == user_id,
        )
        .first()
    )

    if parent is None:
        raise ValueError("Categoria pai não encontrada.")

    if parent.parent_id is not None:
        raise ValueError("Não é permitido criar mais de 2 níveis de categoria.")

    if parent.classification != classification:
        raise ValueError(
            "A subcategoria precisa ter a mesma classificação da categoria pai."
        )

    return parent


def create_category(
    db: Session,
    user_id: int,
    name: str,
    color: str,
    lucide_icon: str,
    classification: str,
    parent_id: int | None = None,
) -> Category:
    existing_category = (
        db.query(Category)
        .filter(
            Category.user_id == user_id,
            func.lower(Category.name) == name.lower(),
        )
        .first()
    )

    if existing_category is not None:
        raise ValueError("Já existe uma categoria com esse nome.")

    parent = validate_category_parent(
        db=db,
        user_id=user_id,
        parent_id=parent_id,
        classification=classification,
    )

    if parent is not None:
        color = parent.color

    category = Category(
        user_id=user_id,
        parent_id=parent_id,
        name=name,
        color=color,
        lucide_icon=lucide_icon,
        classification=classification,
    )

    db.add(category)
    db.commit()
    db.refresh(category)

    return category


def list_categories(
    db: Session,
    user_id: int,
    classification: str | None = None,
    roots_only: bool = False,
) -> list[Category]:
    query = db.query(Category).filter(Category.user_id == user_id)

    if classification:
        query = query.filter(Category.classification == classification)

    if roots_only:
        query = query.filter(Category.parent_id.is_(None))

    return query.order_by(Category.name.asc()).all()


def get_category(
    db: Session,
    user_id: int,
    category_id: int,
) -> Category | None:
    return (
        db.query(Category)
        .filter(
            Category.id == category_id,
            Category.user_id == user_id,
        )
        .first()
    )


def replace_and_delete_category(
    db: Session,
    user_id: int,
    category_id: int,
    replacement_category_id: int | None,
) -> None:
    category = get_category(
        db=db,
        user_id=user_id,
        category_id=category_id,
    )

    if category is None:
        raise ValueError("Categoria não encontrada.")

    replacement = None

    if replacement_category_id is not None:
        replacement = get_category(
            db=db,
            user_id=user_id,
            category_id=replacement_category_id,
        )

        if replacement is None:
            raise ValueError("Categoria substituta não encontrada.")

    db.query(Transaction).filter(
        Transaction.user_id == user_id,
        Transaction.category_id == category.id,
    ).update(
        {
            "category_id": replacement.id if replacement else None,
            "category_name": replacement.name if replacement else None,
        },
        synchronize_session=False,
    )

    db.delete(category)
    db.commit()


def create_category_rule(
    db: Session,
    user_id: int,
    category_id: int,
    pattern: str,
    match_type: str = "contains",
    field: str = "description",
    priority: int = 100,
) -> CategoryRule:
    category = get_category(
        db=db,
        user_id=user_id,
        category_id=category_id,
    )

    if category is None:
        raise ValueError("Categoria não encontrada.")

    rule = CategoryRule(
        user_id=user_id,
        category_id=category_id,
        pattern=pattern.strip(),
        match_type=match_type,
        field=field,
        priority=priority,
        is_active=True,
    )

    db.add(rule)
    db.commit()
    db.refresh(rule)

    return rule


def list_category_rules(
    db: Session,
    user_id: int,
) -> list[CategoryRule]:
    return (
        db.query(CategoryRule)
        .filter(CategoryRule.user_id == user_id)
        .order_by(CategoryRule.priority.asc(), CategoryRule.id.asc())
        .all()
    )


def transaction_text_for_field(
    transaction: Transaction,
    field: str,
) -> str:
    if field == "merchant":
        return transaction.merchant_name or ""

    if field == "description":
        return transaction.display_description or ""

    return " ".join(
        [
            transaction.display_description or "",
            transaction.merchant_name or "",
        ]
    )


def rule_matches_transaction(
    rule: CategoryRule,
    transaction: Transaction,
) -> bool:
    text = transaction_text_for_field(transaction, rule.field).lower()
    pattern = rule.pattern.lower().strip()

    if not pattern:
        return False

    if rule.match_type == "equals":
        return text == pattern

    if rule.match_type == "starts_with":
        return text.startswith(pattern)

    return pattern in text


def find_category_for_transaction(
    db: Session,
    user_id: int,
    transaction: Transaction,
) -> Category | None:
    rules = (
        db.query(CategoryRule)
        .join(Category, Category.id == CategoryRule.category_id)
        .filter(
            CategoryRule.user_id == user_id,
            CategoryRule.is_active.is_(True),
            Category.classification == transaction.cashflow_type,
        )
        .order_by(CategoryRule.priority.asc(), CategoryRule.id.asc())
        .all()
    )

    for rule in rules:
        if rule_matches_transaction(rule, transaction):
            return rule.category

    return None


def categorize_transaction(
    db: Session,
    user_id: int,
    transaction: Transaction,
) -> Transaction:
    if transaction.category_id is not None:
        return transaction

    category = find_category_for_transaction(
        db=db,
        user_id=user_id,
        transaction=transaction,
    )

    if category is None:
        return transaction

    transaction.category_id = category.id
    transaction.category_name = category.name

    db.add(transaction)

    return transaction


def categorize_uncategorized_transactions(
    db: Session,
    user_id: int,
) -> dict[str, Any]:
    transactions = (
        db.query(Transaction)
        .filter(
            Transaction.user_id == user_id,
            Transaction.category_id.is_(None),
            Transaction.cashflow_type.in_(["income", "expense"]),
        )
        .all()
    )

    categorized_count = 0

    for transaction in transactions:
        before = transaction.category_id

        categorize_transaction(
            db=db,
            user_id=user_id,
            transaction=transaction,
        )

        if before is None and transaction.category_id is not None:
            categorized_count += 1

    db.commit()

    return {
        "processed": len(transactions),
        "categorized": categorized_count,
        "uncategorized": len(transactions) - categorized_count,
    }