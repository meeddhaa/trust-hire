/**
 * Gemini relay — the one place the API key touches the network. Forces
 * structured JSON output via `responseSchema` so the response parses
 * straight into a UI model with no prose-wrapper stripping, per the brief
 * ("Gemini Flash API ... structured to return JSON only").
 */

interface Env {
  GEMINI_API_KEY: string;
  GEMINI_MODEL: string;
}

export class GeminiError extends Error {}

/** A minimal subset of the Gemini `responseSchema` (OpenAPI-style) shape —
 * just enough for the schemas this Worker uses. Array items can themselves
 * be an OBJECT (e.g. resume `experience` entries), one level deep only —
 * nothing here needs more nesting than that yet. */
interface GeminiJsonSchemaProperty {
  type: 'STRING' | 'INTEGER' | 'ARRAY' | 'OBJECT';
  items?: {
    type: 'STRING' | 'OBJECT';
    properties?: Record<string, { type: 'STRING' }>;
    required?: string[];
  };
}

export interface GeminiJsonSchema {
  type: 'OBJECT';
  properties: Record<string, GeminiJsonSchemaProperty>;
  required: string[];
}

export interface InlineFile {
  mimeType: string;
  base64Data: string;
}

export async function callGeminiForJson<T>(
  env: Env,
  systemInstruction: string,
  userPrompt: string,
  schema: GeminiJsonSchema,
  /** Extra document/image parts (e.g. a resume PDF) sent alongside the
   * text prompt — Gemini reads these natively, no separate text-extraction
   * step needed. Used by the resume-tailoring endpoint. */
  inlineFiles: InlineFile[] = [],
): Promise<T> {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${env.GEMINI_MODEL}:generateContent?key=${env.GEMINI_API_KEY}`;

  const fileParts = inlineFiles.map((file) => ({
    inlineData: { mimeType: file.mimeType, data: file.base64Data },
  }));

  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      contents: [{ role: 'user', parts: [...fileParts, { text: userPrompt }] }],
      systemInstruction: { parts: [{ text: systemInstruction }] },
      generationConfig: {
        responseMimeType: 'application/json',
        responseSchema: schema,
        temperature: 0.2,
      },
    }),
  });

  if (!res.ok) {
    // Gemini error bodies are small (a JSON error object), safe to buffer.
    throw new GeminiError(`Gemini request failed (${res.status}): ${await res.text()}`);
  }

  const body = await res.json<{
    candidates?: { content?: { parts?: { text?: string }[] } }[];
  }>();
  const text = body.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!text) throw new GeminiError('Gemini response had no content');

  try {
    return JSON.parse(text) as T;
  } catch {
    throw new GeminiError('Gemini response was not valid JSON despite responseSchema');
  }
}
