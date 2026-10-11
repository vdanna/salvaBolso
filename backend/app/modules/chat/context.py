import re
from decimal import Decimal
from typing import Any

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.db.models import Transaction
from app.modules.summaries.service import (
    get_available_transaction_months,
    get_cashflow_summary,
    get_consumption_summary,
    get_credit_card_installments_summary,
    get_credit_card_merchants_summary,
    get_health_score,
    get_overall_dashboard_summary,
)


def get_latest_transaction_month(
    db: Session,
    user_id: int,
) -> str | None:
    statement = (
        select(func.max(Transaction.date))
        .where(Transaction.user_id == user_id)
    )

    latest_date = db.scalar(statement)

    if latest_date is None:
        return None

    return latest_date.strftime("%Y-%m")


def money_to_text(value: Any) -> str:
    if value is None:
        return "não informado"

    decimal_value = Decimal(value)

    return f"R$ {decimal_value:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")


MONTH_NAMES = {
    "janeiro": "01",
    "jan": "01",
    "fevereiro": "02",
    "fev": "02",
    "março": "03",
    "marco": "03",
    "mar": "03",
    "abril": "04",
    "abr": "04",
    "maio": "05",
    "mai": "05",
    "junho": "06",
    "jun": "06",
    "julho": "07",
    "jul": "07",
    "agosto": "08",
    "ago": "08",
    "setembro": "09",
    "set": "09",
    "outubro": "10",
    "out": "10",
    "novembro": "11",
    "nov": "11",
    "dezembro": "12",
    "dez": "12",
}


def detect_requested_period(
    text: str,
    available_months: list[str],
) -> str | None:
    normalized = text.lower().strip()

    general_terms = [
        "todos os meses",
        "todo o período",
        "todo periodo",
        "período completo",
        "periodo completo",
        "balanço geral",
        "balanco geral",
        "geral",
    ]

    if any(term in normalized for term in general_terms):
        return "all"

    match = re.search(r"(20\d{2})[-/](0[1-9]|1[0-2])", normalized)

    if match:
        return f"{match.group(1)}-{match.group(2)}"

    match = re.search(r"\b(0?[1-9]|1[0-2])/(20\d{2})\b", normalized)

    if match:
        month = match.group(1).zfill(2)
        year = match.group(2)

        return f"{year}-{month}"

    for name, month_number in MONTH_NAMES.items():
        if name in normalized:
            year_match = re.search(r"\b(20\d{2})\b", normalized)

            if year_match:
                return f"{year_match.group(1)}-{month_number}"

            matching_available_months = [
                month
                for month in available_months
                if month.endswith(f"-{month_number}")
            ]

            if matching_available_months:
                return sorted(matching_available_months, reverse=True)[0]

    return None


def build_overall_context_text(
    overall: dict,
) -> str:
    cashflow = overall["cashflow"]
    consumption = overall["consumption"]
    health_score = overall["health_score"]
    merchants = overall["merchants"]
    installments = overall["installments"]
    categories = overall.get("categories", {"items": []})

    merchants_text = []

    for item in merchants["items"][:8]:
        merchants_text.append(
            "- "
            f"{item['merchant_name']}: "
            f"{money_to_text(item['total'])} "
            f"({item['transaction_count']} transações)"
        )

    installments_text = []

    for item in installments["items"][:8]:
        installments_text.append(
            "- "
            f"{item['merchant_name']}: "
            f"{money_to_text(item['amount_in_month'])}; "
            f"parcelas vistas: {item['installments_seen']}; "
            f"total de parcelas: {item['installment_total']}"
        )

    categories_text = []

    for item in categories.get("items", [])[:8]:
        categories_text.append(
            "- "
            f"{item['category_name']}: "
            f"{money_to_text(item['total'])} "
            f"({item['transaction_count']} transações)"
        )

    warnings = []
    warnings.extend(cashflow.get("warnings", []))
    warnings.extend(consumption.get("warnings", []))
    warnings.extend(health_score.get("warnings", []))

    return f"""
Período analisado: balanço geral de todos os meses disponíveis
Meses disponíveis: {", ".join(overall.get("months", [])) or "não informado"}

RESUMO GERAL DE CAIXA:
- Entradas brutas: {money_to_text(cashflow["gross_inflow"])}
- Saídas brutas: {money_to_text(cashflow["gross_outflow"])}
- Saldo líquido de caixa: {money_to_text(cashflow["net_cashflow"])}
- Renda identificada: {money_to_text(cashflow["income"])}
- Despesas na conta corrente: {money_to_text(cashflow["expenses"])}
- Pagamentos de fatura/dívida: {money_to_text(cashflow["debt_payments"])}
- Pagamentos de fatura conciliados: {money_to_text(cashflow["reconciled_card_bill_payments"])}
- Pagamentos de fatura não conciliados: {money_to_text(cashflow["unreconciled_card_bill_payments"])}

RESUMO GERAL DE CONSUMO:
- Consumo total real: {money_to_text(consumption["total_consumption"])}
- Consumo via conta corrente: {money_to_text(consumption["checking_consumption"])}
- Consumo via cartão de crédito: {money_to_text(consumption["credit_card_consumption"])}
- Débito: {money_to_text(consumption["debit_card_total"])}
- Pix: {money_to_text(consumption["pix_total"])}
- Boletos: {money_to_text(consumption["bank_slip_total"])}
- Cartão de crédito: {money_to_text(consumption["credit_card_total"])}
- Parcelados: {money_to_text(consumption["installment_total"])}
- Compras à vista: {money_to_text(consumption["single_purchase_total"])}

SCORE FINANCEIRO GERAL:
- Score: {health_score["score"]}/100
- Status: {health_score["status"]}
- Taxa de consumo sobre renda: {health_score["consumption_rate"]}%
- Taxa de pagamento de dívida/fatura sobre renda: {health_score["debt_payment_rate"]}%
- Margem de caixa: {health_score["cash_margin_rate"]}%

GASTOS POR CATEGORIA:
{chr(10).join(categories_text) if categories_text else "- Nenhuma categoria encontrada."}

PRINCIPAIS LOJISTAS DO CARTÃO:
{chr(10).join(merchants_text) if merchants_text else "- Nenhum lojista encontrado."}

COMPRAS PARCELADAS:
{chr(10).join(installments_text) if installments_text else "- Nenhuma compra parcelada encontrada."}

AVISOS DO SISTEMA:
{chr(10).join(f"- {warning}" for warning in warnings) if warnings else "- Nenhum aviso relevante."}
""".strip()

def build_financial_context(
    db: Session,
    user_id: int,
    month: str | None,
    user_question: str = "",
) -> dict[str, Any]:
    available_months = get_available_transaction_months(
        db=db,
        user_id=user_id,
    )

    detected_period = detect_requested_period(
        text=user_question,
        available_months=available_months,
    )

    selected_period = month or detected_period

    if selected_period == "all":
        overall = get_overall_dashboard_summary(
            db=db,
            user_id=user_id,
        )

        return {
            "month": "all",
            "has_data": bool(overall.get("months")),
            "text": build_overall_context_text(overall),
        }

    selected_month = selected_period or get_latest_transaction_month(
        db=db,
        user_id=user_id,
    )

    if selected_month is None:
        return {
            "month": None,
            "has_data": False,
            "text": (
                "Ainda não há transações importadas para este usuário. "
                "Oriente o usuário a importar os CSVs antes de fazer análises financeiras."
            ),
        }

    cashflow = get_cashflow_summary(
        db=db,
        user_id=user_id,
        month=selected_month,
    )

    consumption = get_consumption_summary(
        db=db,
        user_id=user_id,
        month=selected_month,
    )

    merchants = get_credit_card_merchants_summary(
        db=db,
        user_id=user_id,
        month=selected_month,
    )

    installments = get_credit_card_installments_summary(
        db=db,
        user_id=user_id,
        month=selected_month,
    )

    health_score = get_health_score(
        db=db,
        user_id=user_id,
        month=selected_month,
    )

    top_transactions_text = []

    for transaction in consumption["top_transactions"][:8]:
        top_transactions_text.append(
            "- "
            f"{transaction['date']} | "
            f"{transaction['display_description']} | "
            f"{money_to_text(transaction['amount_abs'])} | "
            f"{transaction['payment_method']}"
        )

    merchants_text = []

    for item in merchants["items"][:8]:
        merchants_text.append(
            "- "
            f"{item['merchant_name']}: "
            f"{money_to_text(item['total'])} "
            f"({item['transaction_count']} transações)"
        )

    installments_text = []

    for item in installments["items"][:8]:
        installments_text.append(
            "- "
            f"{item['merchant_name']}: "
            f"{money_to_text(item['amount_in_month'])} no mês; "
            f"parcelas vistas: {item['installments_seen']}; "
            f"total de parcelas: {item['installment_total']}"
        )

    warnings = []
    warnings.extend(cashflow.get("warnings", []))
    warnings.extend(consumption.get("warnings", []))
    warnings.extend(health_score.get("warnings", []))

    context_text = f"""
Mês analisado: {selected_month}

RESUMO DE CAIXA:
- Entradas brutas: {money_to_text(cashflow["gross_inflow"])}
- Saídas brutas: {money_to_text(cashflow["gross_outflow"])}
- Saldo líquido de caixa: {money_to_text(cashflow["net_cashflow"])}
- Renda identificada: {money_to_text(cashflow["income"])}
- Despesas na conta corrente: {money_to_text(cashflow["expenses"])}
- Pagamentos de fatura/dívida: {money_to_text(cashflow["debt_payments"])}
- Pagamentos de fatura conciliados: {money_to_text(cashflow["reconciled_card_bill_payments"])}
- Pagamentos de fatura não conciliados: {money_to_text(cashflow["unreconciled_card_bill_payments"])}
- Valor adicionado na conta via cartão de crédito: {money_to_text(cashflow["liability_increase"])}

RESUMO DE CONSUMO:
- Consumo total real: {money_to_text(consumption["total_consumption"])}
- Consumo via conta corrente: {money_to_text(consumption["checking_consumption"])}
- Consumo via cartão de crédito: {money_to_text(consumption["credit_card_consumption"])}
- Débito: {money_to_text(consumption["debit_card_total"])}
- Pix: {money_to_text(consumption["pix_total"])}
- Boletos: {money_to_text(consumption["bank_slip_total"])}
- Cartão de crédito: {money_to_text(consumption["credit_card_total"])}
- NuPay: {money_to_text(consumption["nupay_total"])}
- Parcelados: {money_to_text(consumption["installment_total"])}
- Compras à vista: {money_to_text(consumption["single_purchase_total"])}

SCORE FINANCEIRO PRELIMINAR:
- Score: {health_score["score"]}/100
- Status: {health_score["status"]}
- Taxa de consumo sobre renda: {health_score["consumption_rate"]}%
- Taxa de pagamento de dívida/fatura sobre renda: {health_score["debt_payment_rate"]}%
- Margem de caixa: {health_score["cash_margin_rate"]}%

MAIORES TRANSAÇÕES DE CONSUMO:
{chr(10).join(top_transactions_text) if top_transactions_text else "- Nenhuma transação de consumo encontrada."}

PRINCIPAIS LOJISTAS DO CARTÃO:
{chr(10).join(merchants_text) if merchants_text else "- Nenhum lojista encontrado."}

COMPRAS PARCELADAS:
{chr(10).join(installments_text) if installments_text else "- Nenhuma compra parcelada encontrada."}

AVISOS DO SISTEMA:
{chr(10).join(f"- {warning}" for warning in warnings) if warnings else "- Nenhum aviso relevante."}
""".strip()

    return {
        "month": selected_month,
        "has_data": True,
        "text": context_text,
    }


def build_financial_prompt(
    user_question: str,
    financial_context: dict[str, Any],
) -> str:
    return f"""
Você é um assistente financeiro pessoal dentro de um aplicativo de controle financeiro.

REGRAS IMPORTANTES:
1. Responda em português do Brasil.
2. Use apenas os dados fornecidos no CONTEXTO FINANCEIRO.
3. Não invente transações, rendas, dívidas ou categorias.
4. Explique a diferença entre fluxo de caixa e consumo quando isso for relevante.
5. Nunca conte pagamento de fatura como consumo, pois isso geraria dupla contagem.
6. Pagamento de fatura é saída de caixa e pagamento de dívida.
7. Pagamento recebido no cartão é redução de dívida, não renda.
8. Não dê recomendação de investimento específico.
9. Não prometa resultado financeiro.
10. Seja direto, prático e educativo.
11. Quando houver poucos dados, diga que a análise é limitada.
12. Priorize diagnóstico e ação prática.
13. Responda de forma curta e direta.
14. Não escreva textos longos.
15. Termine com um próximo passo concreto.

CONTEXTO FINANCEIRO:
{financial_context["text"]}

PERGUNTA DO USUÁRIO:
{user_question}

RESPOSTA:
""".strip()