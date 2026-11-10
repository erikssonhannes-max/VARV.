import { load, save } from './data'

// Ett pass som körs på klockan. Samma regler som passläget i appen:
// en övning med flera set går set för set, tiden sparas på övningar där tiden betyder något,
// och en skippad övning sparas inte. Passet sparas på klockan efter varje steg,
// så att det går att fortsätta om appen stängs.

export function startWorkout(pass) {
  const now = Date.now()
  const w = {
    pass,
    items: JSON.parse(JSON.stringify(pass.items || [])),
    done: (pass.items || []).map(() => false),
    secs: (pass.items || []).map(() => null),
    cur: 0,
    setsDone: 0,
    startedAt: now,
    pausedMs: 0,
    pausedAt: null,
    exAt: 0,
    finished: false,
    saved: false,
    id: 'w' + now.toString(36) + Math.floor(Math.random() * 1679616).toString(36)
  }
  save('workout', w)
  return w
}

export function currentWorkout() {
  const w = load('workout', null)
  if (!w || !w.items || !w.items.length) return null
  // Ett pass som har legat i över ett dygn fortsätter man inte.
  if (Date.now() - w.startedAt > 24 * 3600 * 1000) {
    save('workout', null)
    return null
  }
  return w
}

export function clearWorkout() {
  save('workout', null)
}

export function elapsed(w) {
  const now = w.pausedAt || Date.now()
  return Math.max(0, (now - w.startedAt - w.pausedMs) / 1000)
}

export function exerciseElapsed(w) {
  return Math.max(0, elapsed(w) - w.exAt)
}

export function setCount(w) {
  const it = w.items[w.cur]
  return it && it.sets ? it.sets.length : 0
}

export function moreSets(w) {
  const n = setCount(w)
  return n > 1 && w.setsDone < n - 1
}

export function isLast(w) {
  return w.cur >= w.items.length - 1
}

export function doneCount(w) {
  return w.done.filter(Boolean).length
}

// Övningar där tiden är en del av resultatet: sträckor, kalorier, tidsövningar och stationer.
function timed(it) {
  return it.k === 'd' || it.k === 'c' || it.k === 't' || (it.k === 'r' && it.st === 1)
}

export function pauseOrResume(w) {
  if (w.pausedAt) {
    w.pausedMs += Date.now() - w.pausedAt
    w.pausedAt = null
  } else {
    w.pausedAt = Date.now()
  }
  save('workout', w)
}

// Nästa set, eller nästa övning när sista setet är klart.
export function advance(w) {
  if (w.finished || w.pausedAt) return
  if (moreSets(w)) {
    w.setsDone += 1
    save('workout', w)
    return
  }
  const it = w.items[w.cur]
  const sec = Math.max(1, Math.round(exerciseElapsed(w)))
  w.done[w.cur] = true
  if (timed(it)) {
    w.secs[w.cur] = sec
    // En ensam sträcka eller station får sin tid direkt i setet, som i appen.
    if (it.sets && it.sets.length === 1) it.sets[0].t = sec
  }
  step(w)
}

// Hoppar över övningen. Den sparas inte med passet.
export function skip(w) {
  if (w.finished) return
  step(w)
}

function step(w) {
  if (isLast(w)) {
    finish(w)
    return
  }
  w.cur += 1
  w.setsDone = 0
  w.exAt = elapsed(w)
  save('workout', w)
}

export function finish(w) {
  if (!w.pausedAt) w.pausedAt = Date.now()
  w.finished = true
  save('workout', w)
}

// Passet i den form som kontot tar emot. Bara övningar som blev klara följer med.
export function result(w) {
  const d = new Date(w.startedAt)
  const two = (n) => (n < 10 ? '0' + n : '' + n)
  const items = []
  w.items.forEach((it, i) => {
    if (!w.done[i]) return
    const o = { ex: it.ex, n: it.n, k: it.k, w: it.w, st: it.st, sets: it.sets || [] }
    if (w.secs[i] != null) o.sec = w.secs[i]
    items.push(o)
  })
  const r = {
    date: d.getFullYear() + '-' + two(d.getMonth() + 1) + '-' + two(d.getDate()),
    total: Math.round(elapsed(w)),
    name: w.pass.n,
    items
  }
  if (w.pass.t) r.type = w.pass.t
  return r
}

// Lägger passet i kön på klockan. Det skickas av flush().
export function queueResult(w) {
  const queue = load('pending', [])
  if (!queue.some((x) => x.id === w.id)) queue.push({ id: w.id, pass: result(w) })
  save('pending', queue)
  w.saved = true
  save('workout', w)
}
