// resolve-line: recebe uma linha que o Tobi não reconheceu ("?") e uma lista de candidatos
// da base local, e pergunta ao Jev (TypeSafe) se é comida e qual candidato é.
// O Jev só escolhe dentro da lista: nenhum número nutricional sai daqui.

const JEV_URL = "https://api.typesafe.ai/v1/systemone";
const NONE = "nenhum";
const MAX_TEXT = 200;
const MAX_CANDIDATES = 40;
const MAX_NAME = 120;
// Abaixo disso a linha continua "?". Fica aqui pra ajustar sem atualizar o app.
const MIN_FOOD = 0.5;
const MIN_CONFIDENCE = 0.6;

type Candidate = { id: string; name: string };

type Answer = {
  isFood: number;
  /** id do candidato escolhido, ou null se não é comida, é "nenhum" ou a confiança é baixa. */
  match: string | null;
  choice: string | null;
  confidence: number;
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function parse(body: unknown): { text: string; candidates: Candidate[] } | string {
  if (typeof body !== "object" || body === null) return "corpo inválido";
  const { text, candidates } = body as Record<string, unknown>;
  if (typeof text !== "string" || !text.trim()) return "text obrigatório";
  if (text.length > MAX_TEXT) return `text passa de ${MAX_TEXT} caracteres`;
  if (!Array.isArray(candidates) || candidates.length === 0) return "candidates obrigatório";
  if (candidates.length > MAX_CANDIDATES) return `no máximo ${MAX_CANDIDATES} candidates`;
  const clean: Candidate[] = [];
  const seen = new Set<string>();
  for (const c of candidates) {
    const { id, name } = (c ?? {}) as Record<string, unknown>;
    if (typeof id !== "string" || typeof name !== "string" || !id || !name) return "candidate inválido";
    if (name.length > MAX_NAME || id.length > MAX_NAME) return "candidate grande demais";
    if (seen.has(id)) continue;
    seen.add(id);
    clean.push({ id, name });
  }
  return { text: text.trim(), candidates: clean };
}

async function askJev(key: string, text: string, candidates: Candidate[]): Promise<Response> {
  // As opções vão como "c0", "c1"... pro id da base não influenciar a escolha.
  const criteria: Record<string, string> = {};
  candidates.forEach((c, i) => (criteria[`c${i}`] = c.name));
  criteria[NONE] = "Nenhum alimento da lista corresponde ao que a linha descreve";

  const body = JSON.stringify({
    model: "jev-latest",
    state: { linha: text },
    questions: {
      is_food: {
        type: "noul",
        instructions: "A `linha` é uma anotação de algo que a pessoa comeu ou bebeu?",
        criteria: {
          true: "Descreve uma comida, bebida, prato ou ingrediente consumido",
          false: "É outra coisa: tarefa, lembrete, exercício, humor ou texto sem relação com comida",
        },
      },
      item: {
        type: "choice",
        instructions:
          "Qual alimento da lista é o mesmo que a `linha` descreve? Ignore quantidades e medidas. Se nenhum for o mesmo alimento, escolha nenhum.",
        criteria,
      },
    },
  });

  for (let attempt = 0; ; attempt++) {
    const res = await fetch(JEV_URL, {
      method: "POST",
      headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
      body,
      signal: AbortSignal.timeout(8000),
    });
    if ((res.status === 429 || res.status === 529) && attempt === 0) {
      await new Promise((r) => setTimeout(r, 400));
      continue;
    }
    return res;
  }
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "use POST" }, 405);

  const key = Deno.env.get("TYPESAFE_API_KEY");
  if (!key) return json({ error: "TYPESAFE_API_KEY não configurada" }, 500);

  let input: unknown;
  try {
    input = await req.json();
  } catch {
    return json({ error: "JSON inválido" }, 400);
  }
  const parsed = parse(input);
  if (typeof parsed === "string") return json({ error: parsed }, 400);
  const { text, candidates } = parsed;

  let res: Response;
  try {
    res = await askJev(key, text, candidates);
  } catch (e) {
    return json({ error: `Jev não respondeu: ${(e as Error).name}` }, 504);
  }
  if (!res.ok) {
    console.error("jev", res.status, await res.text());
    return json({ error: `Jev respondeu ${res.status}` }, 502);
  }

  const data = await res.json();
  const isFood: number = data.answers?.is_food?.noul ?? 0;
  const item = data.answers?.item ?? {};
  const option: string | undefined = item.choice;
  const confidence: number = item.confidence ?? 0;
  const choice = option && option !== NONE ? candidates[Number(option.slice(1))]?.id ?? null : null;
  const match = isFood >= MIN_FOOD && confidence >= MIN_CONFIDENCE ? choice : null;

  return json({ isFood, match, choice, confidence } satisfies Answer);
});
