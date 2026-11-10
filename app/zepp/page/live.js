import { BasePage } from '@zeppos/zml/base-page'
import { replace } from '@zos/router'
import { px } from '@zos/utils'
import * as display from '@zos/display'
import * as sensor from '@zos/sensor'
import { canvas, setText, W, H, PAD, INNER, ACCENT, GREEN, WHITE, MUTED, TILE, TILE_PRESS } from '../shared/ui'
import { flush, fmtTime, load } from '../shared/data'
import * as wo from '../shared/workout'

// Passläget och sammanfattningen när passet är klart.
let vibrator = null
function buzz() {
  try {
    if (!vibrator && sensor.Vibrator) vibrator = new sensor.Vibrator()
    if (vibrator) vibrator.start()
  } catch (e) {}
}

// Skärmen ska inte släckas mitt i ett pass.
function keepAwake(on) {
  try {
    if (display.setPageBrightTime) display.setPageBrightTime({ brightTime: on ? 600000 : 10000 })
    if (on && display.pauseDropWristScreenOff) display.pauseDropWristScreenOff({ duration: 0 })
    if (!on && display.resetDropWristScreenOff) display.resetDropWristScreenOff()
  } catch (e) {}
}

Page(
  BasePage({
    state: { ui: null, w: null, menu: false, timer: null, clock: null, total: null, sending: false, sent: false },

    onInit() {
      this.state.w = wo.currentWorkout()
    },

    build() {
      this.state.ui = canvas()
      if (!this.state.w) {
        replace({ url: 'page/index' })
        return
      }
      keepAwake(true)
      this.draw()
      this.state.timer = setInterval(() => this.tick(), 1000)
    },

    onDestroy() {
      if (this.state.timer) clearInterval(this.state.timer)
      keepAwake(false)
    },

    tick() {
      const w = this.state.w
      if (!w || w.finished || this.state.menu) return
      if (this.state.clock) setText(this.state.clock, fmtTime(wo.exerciseElapsed(w)))
      if (this.state.total) setText(this.state.total, (w.pausedAt ? 'Pausat ' : 'Passet ') + fmtTime(wo.elapsed(w)))
    },

    draw() {
      const w = this.state.w
      const ui = this.state.ui
      ui.clear()
      this.state.clock = null
      this.state.total = null
      if (w.finished) return this.drawSummary()
      if (this.state.menu) return this.drawMenu()

      const it = w.items[w.cur]
      const sets = wo.setCount(w)
      let y = Math.round(H * 0.08)
      ui.text(y, px(32), w.cur + 1 + ' av ' + w.items.length, { size: px(22), color: MUTED })
      y += px(34)
      ui.text(y, px(76), it.n, { size: px(34) })
      y += px(80)
      let goal = it.g || ''
      if (sets > 1) goal = 'Set ' + (w.setsDone + 1) + ' av ' + sets + (goal ? ' - ' + goal : '')
      ui.text(y, px(36), goal, { size: px(24), color: sets > 1 ? GREEN : MUTED, nowrap: true })
      y += px(40)
      this.state.clock = ui.text(y, px(84), fmtTime(wo.exerciseElapsed(w)), { size: px(72), color: w.pausedAt ? MUTED : WHITE })
      y += px(86)
      this.state.total = ui.text(y, px(32), (w.pausedAt ? 'Pausat ' : 'Passet ') + fmtTime(wo.elapsed(w)), { size: px(22), color: MUTED })
      y += px(40)

      const label = w.pausedAt ? 'Fortsätt' : wo.moreSets(w) ? 'Nästa set' : wo.isLast(w) ? 'Klar' : 'Nästa'
      ui.button(y, px(76), label, () => {
        if (w.pausedAt) wo.pauseOrResume(w)
        else wo.advance(w)
        buzz()
        this.draw()
      })
      y += px(88)

      // Pausa, skippa och avsluta på en rad
      const gap = px(8)
      const bw = Math.round((INNER - gap * 2) / 3)
      const small = { color: TILE, press: TILE_PRESS, size: px(22), w: bw }
      ui.button(y, px(60), w.pausedAt ? 'Kör' : 'Paus', () => {
        wo.pauseOrResume(w)
        this.draw()
      }, Object.assign({ x: PAD }, small))
      ui.button(y, px(60), 'Skippa', () => {
        wo.skip(w)
        buzz()
        this.draw()
      }, Object.assign({ x: PAD + bw + gap }, small))
      ui.button(y, px(60), 'Avsluta', () => {
        this.state.menu = true
        this.draw()
      }, Object.assign({ x: PAD + (bw + gap) * 2 }, small))
    },

    drawMenu() {
      const w = this.state.w
      const ui = this.state.ui
      let y = Math.round(H * 0.16)
      ui.text(y, px(56), 'Avsluta passet?', { size: px(32) })
      y += px(72)
      if (wo.doneCount(w) > 0) {
        ui.button(y, px(72), 'Avsluta och spara', () => {
          this.state.menu = false
          wo.finish(w)
          this.draw()
        })
        y += px(84)
      }
      ui.button(y, px(72), 'Släng passet', () => {
        wo.clearWorkout()
        replace({ url: 'page/index' })
      }, { color: TILE, press: TILE_PRESS })
      y += px(84)
      ui.button(y, px(72), 'Fortsätt', () => {
        this.state.menu = false
        this.draw()
      }, { color: TILE, press: TILE_PRESS })
    },

    drawSummary() {
      const w = this.state.w
      const ui = this.state.ui
      let y = Math.round(H * 0.1)
      ui.text(y, px(32), 'PASSET ÄR KLART', { size: px(22), color: GREEN })
      y += px(36)
      ui.text(y, px(80), fmtTime(wo.elapsed(w)), { size: px(64) })
      y += px(84)
      ui.text(y, px(64), w.pass.n + ' - ' + wo.doneCount(w) + ' av ' + w.items.length + ' övningar', { size: px(22), color: MUTED })
      y += px(72)

      if (!wo.doneCount(w)) {
        ui.text(y, px(64), 'Du skippade alla övningar, så inget sparas.', { size: px(24) })
        y += px(72)
        ui.button(y, px(72), 'Stäng', () => this.close(), { color: TILE, press: TILE_PRESS })
        return
      }
      if (w.saved) {
        const waiting = load('pending', []).some((x) => x.id === w.id)
        ui.text(y, px(64), this.state.sending ? 'Sparar...' : waiting ? 'Sparas i VARV. så fort telefonen är nära.' : 'Sparat i VARV.', { size: px(24) })
        y += px(72)
        ui.button(y, px(72), 'Klar', () => this.close())
        return
      }
      ui.button(y, px(72), 'Spara', () => this.save())
      y += px(84)
      ui.button(y, px(64), 'Släng passet', () => this.close(), { color: TILE, press: TILE_PRESS, size: px(24) })
    },

    async save() {
      const w = this.state.w
      wo.queueResult(w)
      this.state.sending = true
      this.draw()
      try {
        await flush(this)
      } catch (e) {}
      this.state.sending = false
      this.draw()
    },

    close() {
      wo.clearWorkout()
      replace({ url: 'page/index' })
    }
  })
)
