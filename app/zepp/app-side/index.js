import { BaseSideService } from '@zeppos/zml/base-side'

// Sidotjänsten körs i appen Zepp på telefonen. Den kopplar klockan till kontot med koden från VARV.,
// hämtar passen och sparar pass från klockan. Funktionerna finns i supabase/klocka.sql.
// Samma publika adress och nyckel som webbsidan använder (supabase-config.js).
const URL = 'https://kwjnezbazyahyzsmpuyg.supabase.co/rest/v1/rpc/'
const KEY = 'sb_publishable_rsSw4ZNaOGdesoK8KkA55Q_1qZCngdD'

const storage = () => settings.settingsStorage

function setStatus(text) {
  try {
    storage().setItem('status', text)
  } catch (e) {}
}

async function call(name, args) {
  const r = await fetch({
    url: URL + name,
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      apikey: KEY,
      Authorization: 'Bearer ' + KEY
    },
    body: JSON.stringify(args)
  })
  let body = r.body
  if (typeof body === 'string') {
    try {
      body = body ? JSON.parse(body) : null
    } catch (e) {
      body = null
    }
  }
  const status = r.status || 0
  // Ett fel från databasen har alltid code och message, även om status saknas på någon modell.
  const failed = status ? status < 200 || status >= 300 : !!(body && body.code && body.message)
  if (!failed) return { ok: true, body }
  // Klockan är bortkopplad i appen (28000) eller nyckeln är fel
  if (status === 401 || status === 403 || (body && body.code === '28000')) return { ok: false, code: 'unlinked' }
  // Kontot tar inte emot innehållet, hur många gånger det än skickas
  if (status === 400 || (body && body.code === 'P0001')) return { ok: false, code: 'invalid', message: body && body.message }
  return { ok: false, code: 'net' }
}

function token() {
  return storage().getItem('token') || ''
}

// Byter koden från VARV. mot en egen nyckel för klockan.
async function claim() {
  const code = String(storage().getItem('code') || '').replace(/\s/g, '').toUpperCase()
  if (code.length < 8) return false
  setStatus('Kopplar...')
  let r
  try {
    r = await call('watch_claim', { p_code: code, p_name: 'Amazfit' })
  } catch (e) {
    r = { ok: false, code: 'net' }
  }
  if (r.ok && r.body && r.body.token) {
    storage().setItem('token', r.body.token)
    storage().setItem('code', '')
    setStatus('Kopplad. Öppna VARV. på klockan.')
    return true
  }
  if (r.code === 'invalid') {
    storage().setItem('code', '')
    setStatus('Koden stämmer inte eller har gått ut. Hämta en ny i VARV.')
  } else {
    setStatus('Ingen kontakt med VARV. Kontrollera att telefonen har nät.')
  }
  return false
}

function unlink() {
  storage().setItem('token', '')
  setStatus('Klockan är bortkopplad. Hämta en ny kod i VARV.')
}

// Anrop med klockans nyckel. En nyckel som inte gäller längre tas bort.
async function withToken(name, args) {
  if (!token()) await claim()
  if (!token()) return { ok: false, code: 'unlinked' }
  let r
  try {
    r = await call(name, Object.assign({ p_token: token() }, args))
  } catch (e) {
    return { ok: false, code: 'net' }
  }
  if (!r.ok && r.code === 'unlinked') unlink()
  return r
}

AppSideService(
  BaseSideService({
    onInit() {
      // En kod som skrivs in i inställningarna provas direkt.
      try {
        storage().addListener('change', ({ key, newValue }) => {
          if (key === 'code' && newValue && String(newValue).replace(/\s/g, '').length >= 8) claim()
        })
      } catch (e) {}
    },

    onRequest(req, res) {
      const p = req.params || {}
      const done = (r) => res(null, r)
      if (req.method === 'sync') {
        withToken('watch_sync', {}).then((r) =>
          done(r.ok ? { ok: true, passes: (r.body && r.body.passes) || [] } : r)
        )
      } else if (req.method === 'pass') {
        withToken('watch_pass', { p_id: p.id }).then((r) =>
          done(r.ok ? { ok: true, pass: r.body && r.body.pass } : r)
        )
      } else if (req.method === 'log') {
        withToken('watch_log', { p_id: p.id, p_pass: p.pass }).then((r) => done(r.ok ? { ok: true } : r))
      } else {
        res('okänd fråga')
      }
    },

    onRun() {},

    onDestroy() {}
  })
)
