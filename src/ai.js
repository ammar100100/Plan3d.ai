import { createClient } from '@supabase/supabase-js';

const $ = (id) => document.getElementById(id);
const url = import.meta.env.VITE_SUPABASE_URL;
const key = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY || import.meta.env.VITE_SUPABASE_ANON_KEY;
const client = url && key ? createClient(url, key) : null;

function status(message, bad = false) {
  const el = $('aiStatus');
  if (!el) return;
  el.textContent = message;
  el.className = 'status ' + (bad ? 'bad' : 'good');
}

function showResult(result) {
  const host = $('aiResult');
  host.style.display = 'block';
  const rooms = Array.isArray(result.rooms) ? result.rooms : [];
  const lines = [
    'نوع الرسم: ' + (result.drawing_type || 'غير محدد'),
    'الوحدات: ' + (result.units || 'غير معروفة'),
    'الأبعاد العامة: ' + JSON.stringify(result.overall_dimensions || {}),
    'مستوى الثقة: ' + (result.confidence ?? 'غير محدد'),
    '',
    'الغرف:',
    ...rooms.map((r) => '• ' + (r.name || 'غرفة') + ' — ' + (r.width ?? '?') + ' × ' + (r.length ?? '?') + ' (' + (r.confidence ?? 'دون درجة ثقة') + ')'),
    '',
    'الافتراضات:',
    ...(result.assumptions || []).map((x) => '• ' + x),
    '',
    'تحذيرات وملاحظات:',
    ...(result.warnings || []).map((x) => '• ' + x),
    '',
    'ملاحظة: النتيجة تحتاج مراجعة بشرية ولا تعتبر مخططًا إنشائيًا أو مستندًا صالحًا للتنفيذ.'
  ];
  host.textContent = lines.join('\n');
}

async function analyze() {
  if (!client) {
    status('Supabase is not connected to this deployment yet. Configure VITE_SUPABASE_URL and VITE_SUPABASE_PUBLISHABLE_KEY (or VITE_SUPABASE_ANON_KEY).', true);
    return;
  }
  const button = $('analyzePlan');
  button.disabled = true;
  $('aiResult').style.display = 'none';
  try {
    const { data: sessionData, error: sessionError } = await client.auth.getSession();
    if (sessionError || !sessionData.session) throw new Error('سجّل الدخول أولًا.');
    const projectId = document.body.dataset.currentProjectId;
    if (!projectId) {
      throw new Error('احفظ المشروع والملف الأصلي أولًا، ثم افتح المشروع المحفوظ واضغط تحليل AI.');
    }
    status('جارٍ إرسال المخطط للتحليل…');
    const { data, error } = await client.functions.invoke('analyze-floorplan', {
      body: { project_id: projectId }
    });
    if (error) {
      const message = data?.error || error.message || 'تعذر تشغيل التحليل.';
      throw new Error(message);
    }
    if (data?.error) throw new Error(data.error);
    showResult(data.result || {});
    status('اكتمل التحليل. راجع النتائج قبل اعتماد أي قياس.');
  } catch (error) {
    status(error.message || 'حدث خطأ أثناء التحليل.', true);
  } finally {
    button.disabled = false;
  }
}

$('analyzePlan')?.addEventListener('click', analyze);
