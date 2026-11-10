import { BasePage } from '@zeppos/zml/base-page'
import { replace } from '@zos/router'
import { px } from '@zos/utils'
import { canvas, H, MUTED, WHITE } from '../shared/ui'
import { load, save } from '../shared/data'
import { startWorkout } from '../shared/workout'

// Ett pass innan det startar: övningarna och knappen Starta.
Page(
  BasePage({
    state: { ui: null, id: '', name: '', pass: null, message: 'Hämtar passet...' },

    onInit(params) {
      try {
        const p = JSON.parse(params || '{}')
        this.state.id = p.id || ''
        this.state.name = p.n || ''
      } catch (e) {}
      // Passet som hämtades senast visas direkt, och byts mot det nya när svaret kommer.
      this.state.pass = load('p_' + this.state.id, null)
    },

    build() {
      this.state.ui = canvas()
      this.draw()
      this.fetch()
    },

    async fetch() {
      try {
        const r = await this.request({ method: 'pass', params: { id: this.state.id } })
        if (r && r.ok && r.pass && r.pass.items && r.pass.items.length) {
          this.state.pass = r.pass
          save('p_' + this.state.id, r.pass)
        } else if (!this.state.pass) {
          this.state.message = 'Passet finns inte längre. Gå tillbaka och tryck Uppdatera.'
        }
      } catch (e) {
        if (!this.state.pass) this.state.message = 'Ingen kontakt med telefonen. Försök igen.'
      }
      this.draw()
    },

    draw() {
      const ui = this.state.ui
      if (!ui) return
      ui.clear()
      let y = px(44)
      const pass = this.state.pass
      ui.text(y, px(96), pass ? pass.n : this.state.name, { size: px(34) })
      y += px(104)
      if (!pass) {
        ui.text(y, px(160), this.state.message, { size: px(26), color: MUTED })
        return
      }
      ui.button(y, px(80), 'Starta', () => {
        startWorkout(pass)
        replace({ url: 'page/live' })
      })
      y += px(96)
      pass.items.forEach((it, i) => {
        ui.text(y, px(40), i + 1 + '. ' + it.n, { size: px(26), color: WHITE, nowrap: true })
        y += px(40)
        if (it.g) {
          ui.text(y, px(36), it.g, { size: px(22), color: MUTED, nowrap: true })
          y += px(40)
        }
        y += px(8)
      })
      if (pass.h) {
        ui.text(y, px(200), pass.h, { size: px(22), color: MUTED })
        y += px(200)
      }
      ui.text(y, Math.round(H * 0.25), '')
    }
  })
)
