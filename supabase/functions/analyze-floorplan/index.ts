import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const cors = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info", "Access-Control-Allow-Methods": "POST, OPTIONS" };
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });
function toBase64(bytes: Uint8Array) { let binary = ""; for (let i = 0; i < bytes.length; i += 0x8000) binary += String.fromCharCode(...bytes.subarray(i, i + 0x8000)); return btoa(binary); }

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);
  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) return json({ error: "Sign in is required." }, 401);
  const url = Deno.env.get("SUPABASE_URL"), anon = Deno.env.get("SUPABASE_ANON_KEY");
  if (!url || !anon) return json({ error: "Supabase configuration is incomplete." }, 500);
  const db = createClient(url, anon, { global: { headers: { Authorization: authHeader } }, auth: { persistSession: false, autoRefreshToken: false } });
  const { data: auth, error: authError } = await db.auth.getUser();
  if (authError || !auth.user) return json({ error: "Invalid session." }, 401);
  const apiKey = Deno.env.get("OPENAI_API_KEY");
  if (!apiKey) return json({ error: "AI provider is not configured. Add OPENAI_API_KEY in Supabase Edge Function Secrets.", setup_required: true }, 503);
  try {
    const { project_id } = await req.json();
    if (!/^[0-9a-f-]{36}$/i.test(String(project_id || ""))) return json({ error: "Invalid project_id." }, 400);
    const { data: project } = await db.from("projects").select("id,name,user_id,source_file_path,source_file_name,source_file_type").eq("id", project_id).eq("user_id", auth.user.id).single();
    if (!project) return json({ error: "Project not found or access denied." }, 404);
    if (!project.source_file_path || !project.source_file_type) return json({ error: "Save the project with its source plan first." }, 400);
    if (!["application/pdf","image/png","image/jpeg","image/webp"].includes(project.source_file_type)) return json({ error: "Supported AI input formats: PDF, PNG, JPG, WEBP." }, 415);
    const { data: file, error: downloadError } = await db.storage.from("floor-plans").download(project.source_file_path);
    if (downloadError || !file) return json({ error: "Could not read the private source file." }, 400);
    if (file.size > 20 * 1024 * 1024) return json({ error: "File exceeds 20 MB." }, 413);
    const encoded = toBase64(new Uint8Array(await file.arrayBuffer()));
    const input = project.source_file_type === "application/pdf"
      ? { type: "input_file", filename: project.source_file_name.replace(/[^a-zA-Z0-9._-]/g,"_"), file_data: `data:application/pdf;base64,${encoded}` }
      : { type: "input_image", image_url: `data:${project.source_file_type};base64,${encoded}`, detail: "high" };
    const { data: job, error: jobError } = await db.from("ai_jobs").insert({ user_id: auth.user.id, project_id, source_file_path: project.source_file_path, source_file_name: project.source_file_name, source_file_type: project.source_file_type, status: "processing", model: "gpt-4.1" }).select("id").single();
    if (jobError || !job) return json({ error: "Could not create analysis job." }, 500);
    const aiResponse = await fetch("https://api.openai.com/v1/responses", { method: "POST", headers: { Authorization: `Bearer ${apiKey}`, "Content-Type": "application/json" }, body: JSON.stringify({
      model: "gpt-4.1",
      input: [{ role: "user", content: [
        { type: "input_text", text: "Analyze this architectural floor plan. Return a JSON object with keys: drawing_type, units, overall_dimensions {width,length}, rooms [{name,width,length,confidence}], walls [{start:[x,z],end:[x,z],thickness}], doors [{position:[x,z],width}], windows [{position:[x,z],width}], assumptions [string], warnings [string], confidence (0..1). Use measurements only when clearly supported; otherwise mark unknown. Use a consistent lower-left origin. Illegible text or dimensions must be marked unknown and explained in warnings. This is a draft interpretation requiring human review, not construction documentation." },
        input
      ] }],
      text: { format: { type: "json_object" } }, max_output_tokens: 5000
    }) });
    const ai = await aiResponse.json();
    if (!aiResponse.ok) {
      await db.from("ai_jobs").update({ status: "failed", error_message: "AI provider request failed." }).eq("id", job.id);
      return json({ error: "AI provider request failed.", provider_status: aiResponse.status }, 502);
    }
    const output = (ai.output || []).flatMap((x: any) => x.content || []).find((x: any) => x.type === "output_text")?.text;
    if (!output) throw new Error("No structured AI output");
    const result = JSON.parse(output);
    const { error: saveError } = await db.from("ai_jobs").update({ status: "needs_review", result, updated_at: new Date().toISOString() }).eq("id", job.id);
    if (saveError) throw saveError;
    return json({ job_id: job.id, status: "needs_review", result });
  } catch (e) {
    console.error("analyze-floorplan", e);
    return json({ error: "Analysis failed. Review the source file and retry." }, 500);
  }
});
