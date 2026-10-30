# Plan3D AI — MVP prototype

Bilingual (English/Arabic) web prototype for a floor-plan-to-3D design and 3D-printing workflow.

## Included in this MVP
- Responsive modern dashboard and EN/AR language switch.
- Editable 3D room shell using Three.js + OrbitControls.
- Editable room dimensions, wall thickness, wall height, interior style, and model scale.
- Upload control for PDF/JPG/PNG (image preview; automatic plan parsing is not connected).
- STL export of the current generated sample geometry.
- Local draft persistence in browser localStorage.
- Supabase SQL migration draft for profiles, projects, project assets, print partners, print quotes, and print orders with RLS policies.

## Important limitations
- Uploaded floor plans are previewed but are not automatically interpreted. The 3D model is generated from entered dimensions and sample partitions/furniture.
- STL export is a prototype export, not a validated manufacturing pipeline. Validate mesh integrity, wall thickness, scale, and slicer compatibility before manufacturing.
- Authentication, cloud persistence, AI plan recognition, payment, and print-partner marketplace are not connected yet.

## Run locally
Requires Node.js 20 or newer.

```bash
npm install
npm run dev
```

Open the local URL printed by Vite.

## Build
```bash
npm run build
npm run preview
```

## Supabase setup
1. Create a dedicated Supabase project.
2. Run `supabase/migrations/202610300001_initial_schema.sql` in the SQL editor.
3. Create a private Storage bucket named `floor-plans`.
4. Configure the public URL and publishable key in your deployment environment. Never expose a service-role key in browser code.

## Deploy to Vercel
Import this repository as a Vite project. Use `npm run build` and output directory `dist`.