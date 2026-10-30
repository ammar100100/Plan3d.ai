# Plan3D AI

Bilingual Arabic/English project studio for organizing floor-plan projects, defining room dimensions, reviewing a live Three.js model, and exporting a draft STL.

## Current capabilities
- Responsive Arabic/English interface.
- 3D room-shell preview with orbit, zoom, pan, grid toggle and configurable dimensions.
- Add and edit room spaces, including width, length and position.
- Attach PDF, PNG, JPG or WEBP source plans (20 MB limit).
- Authenticated AI floor-plan analysis endpoint for saved PDF/image source files; returns structured rooms, dimensions, walls, doors, windows, assumptions and warnings for human review.
- Project save/load/delete.
- STL and JSON export.
- Supabase email/password authentication, database persistence and private Storage upload when configured.
- Local project-settings fallback when Supabase is not configured.

## Important limitations
- AI analysis supports saved PDF, PNG, JPG and WEBP plans only. It returns a structured draft interpretation; it does not guarantee correct dimensions or automatically create a construction-ready CAD/3D model. A human must review the result.
- DXF/DWG and arbitrary files are not yet supported by the AI analysis endpoint.
- The current 3D geometry is based on dimensions and room positions entered by the user. It is a draft visualization, not a construction document.
- STL export is a preliminary model export. It has not been validated for watertightness, print tolerances, scale or manufacturing. Review in CAD/mesh-repair/slicer software before production.
- Payments, customer quote workflows, print-partner onboarding, automated AI processing and production notifications are not connected yet.
- Without Supabase environment variables, projects are stored in browser localStorage and source files are not uploaded to cloud storage.
- AI analysis requires a configured `OPENAI_API_KEY` secret in Supabase Edge Function Secrets. The function returns a clear setup-required response until the secret is configured.

## Run locally
Requires Node.js 20+.

```bash
npm install
cp .env.example .env
npm run dev
```

## Supabase setup
1. Create a dedicated Supabase project.
2. Run `supabase/migrations/202610300001_initial_schema.sql` in the Supabase SQL Editor.
3. Create a **private** Storage bucket named `floor-plans`.
4. Set `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` in `.env` (use the project's publishable key for the browser).
5. Enable email/password authentication in Supabase Auth.
6. Add the same two variables in Vercel → Project → Settings → Environment Variables, then redeploy.
7. Deploy `supabase/functions/analyze-floorplan/index.ts` as `analyze-floorplan` with JWT verification enabled.
8. Add `OPENAI_API_KEY` in Supabase → Edge Functions → Secrets. Never add it to browser environment variables.

The browser app uses only the Supabase anon/publishable key and relies on Row Level Security. Never expose a service-role key or AI provider secret in a `VITE_` variable.

## Vercel
- Framework preset: Vite
- Build command: `npm run build`
- Output directory: `dist`
- Install command: `npm install`

## Production readiness checklist
Before accepting paid customer work, complete automated floor-plan extraction, human review/approval, secure cloud setup, file retention/backups, validated mesh generation, error monitoring, privacy/terms, and a tested quote/order workflow.
