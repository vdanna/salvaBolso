from google import genai
from google.genai import errors, types

from app.core.config import get_settings


SYSTEM_INSTRUCTION = """
Você é o assistente financeiro do aplicativo Salva Bolso.

Responda sempre em português do Brasil.

Seu estilo deve ser:
- curto;
- direto;
- prático;
- sem enrolação;
- sem textos longos;
- sem explicações genéricas;
- sem repetir muitos números desnecessários.

Formato preferido:
1. Resposta direta.
2. Motivo principal.
3. Próximo passo recomendado.

Regras:
- Quando o usuário perguntar algo simples, responda em até 5 linhas.
- Quando houver análise financeira, use no máximo 3 tópicos.
- Não faça introduções longas.
- Não diga "com base nos dados fornecidos" toda hora.
- Não use linguagem técnica sem necessidade.
- Se não houver dados suficientes, diga isso de forma objetiva.
"""


def generate_gemini_response(prompt: str) -> str:
    settings = get_settings()

    if not settings.gemini_api_key:
        return (
            "O Gemini ainda não está configurado no backend. "
            "Confira a variável GEMINI_API_KEY no arquivo .env."
        )

    client = genai.Client(
        api_key=settings.gemini_api_key,
    )

    try:
        response = client.models.generate_content(
            model=settings.gemini_model,
            contents=prompt,
            config=types.GenerateContentConfig(
                system_instruction=SYSTEM_INSTRUCTION,
                max_output_tokens=450,
                candidate_count=1,
            ),
        )

    except errors.ServerError as error:
        status_code = getattr(error, "status_code", None)

        if status_code == 503:
            return (
                "O Gemini está temporariamente sobrecarregado. "
                "Tente novamente em alguns minutos."
            )

        return (
            "O Gemini retornou um erro temporário. "
            "Tente novamente em alguns minutos."
        )

    except errors.APIError as error:
        status_code = getattr(error, "status_code", None)

        if status_code == 429:
            return (
                "O limite de uso do Gemini foi atingido no momento. "
                "Tente novamente mais tarde."
            )

        return (
            "Não consegui consultar o Gemini agora. "
            "Tente novamente em alguns minutos."
        )

    except Exception:
        return (
            "Ocorreu um erro inesperado ao consultar o Gemini. "
            "Tente novamente em alguns minutos."
        )

    text = getattr(response, "text", None)

    if not text:
        return (
            "O Gemini respondeu, mas não retornou um texto válido. "
            "Tente reformular a pergunta."
        )

    return text.strip()