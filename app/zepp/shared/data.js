import { LocalStorage } from '@zos/storage'

// Det som sparas på klockan: listan med pass, hämtade pass, passet som pågår och pass som väntar på att sparas.
const store = new LocalStorage()

export function load(key, fallback) {
  try {
    const v = store.getItem(key)
    if (v === undefined || v === null || v === '') return fallback
    return typeof v === 'string' ? JSON.parse(v) : v
  } catch (e) {
    return fallback
  }
}

export function save(key, value) {
  try {
    if (value === null || value === undefined) store.removeItem(key)
    else store.setItem(key, JSON.stringify(value))
  } catch (e) {}
}

// 754 blir "12:34" och 3723 blir "1:02:03"
export function fmtTime(sec) {
  sec = Math.max(0, Math.round(sec || 0))
  const h = Math.floor(sec / 3600)
  const m = Math.floor((sec % 3600) / 60)
  const s = sec % 60
  const two = (n) => (n < 10 ? '0' + n : '' + n)
  return h > 0 ? h + ':' + two(m) + ':' + two(s) : m + ':' + two(s)
}

// Skickar alla pass som väntar till sidotjänsten. Det som inte går fram ligger kvar till nästa gång.
export async function flush(page) {
  let queue = load('pending', [])
  for (const item of queue.slice()) {
    try {
      const r = await page.request({ method: 'log', params: { id: item.id, pass: item.pass } })
      if (r && (r.ok || r.code === 'invalid')) {
        // Ett pass som kontot inte tar emot får inte stoppa kön.
        queue = queue.filter((x) => x.id !== item.id)
        save('pending', queue)
      } else {
        break
      }
    } catch (e) {
      break
    }
  }
  return queue.length
}
