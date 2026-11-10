import { BasePage } from '@zeppos/zml/base-page'
import { push, replace } from '@zos/router'
import { px } from '@zos/utils'
import { canvas, H, MUTED, ACCENT, TILE, TILE_PRESS } from '../shared/ui'
import { load, save, flush } from '../shared/data'
import { currentWorkout } from '../shared/workout'

// Startsidan: listan med förberedda och färdiga pass.
// Ett pass som pågick när appen stängdes öppnas direkt igen.
Page(
  BasePage({
    state: {
      ui: null,
      passes: [],
      message: '',
      pending: 0,
      loading: false
    },

    onInit() {
      if (currentWorkout()) {
        replace({ url: 'page/live' })
        return
      }
      this.state.passes = load('passes', [])
      this.state.pending = load('pending', []).length
      this.state.message = this.state.passes.length ? '' : 'Hämtar dina pass...'
    },

    build() {
      this.state.ui = canvas()
      this.draw()
      this.refresh()
    },

    async refresh() {
      if (this.state.loading) return
      this.state.loading = true
      try {
        const r = await this.request({ method: 'sync' })
        if (r && r.ok) {
          this.state.passes = r.passes || []
          save('passes', this.state.passes)
          this.state.message = this.state.passes.length ? '' : 'Inga pass än. Öppna VARV. på telefonen en gång, så skickas passen hit.'
          this.state.pending = await flush(this)
        } else if (r && r.code === 'unlinked') {
          this.state.passes = []
          save('passes', [])
          this.state.message = 'Koppla klockan: hämta en kod i VARV. under Profil, Inställningar, Klockor. Skriv in den i appen Zepp under VARV., Inställningar.'
        } else if (!this.state.passes.length) {
          this.state.message = 'Ingen kontakt med telefonen. Kontrollera att appen Zepp är igång.'
        }
      } catch (e) {
        if (!this.state.passes.length) this.state.message = 'Ingen kontakt med telefonen. Kontrollera att appen Zepp är igång.'
      }
      this.state.loading = false
      this.draw()
    },

    draw() {
      const ui = this.state.ui
      if (!ui) return
      ui.clear()
      let y = px(40)
      ui.text(y, px(56), 'VARV.', { size: px(40), color: ACCENT })
      y += px(64)

      if (this.state.pending) {
        ui.text(y, px(70), this.state.pending === 1 ? '1 pass väntar på att sparas' : this.state.pending + ' pass väntar på att sparas', {
          size: px(24),
          color: MUTED
        })
        y += px(76)
      }

      if (this.state.message) {
        ui.text(y, px(220), this.state.message, { size: px(26), color: MUTED })
        y += px(230)
      }

      let group = null
      this.state.passes.forEach((p) => {
        if (p.g && p.g !== group) {
          group = p.g
          ui.text(y, px(44), group.toUpperCase(), { size: px(22), color: MUTED })
          y += px(48)
        }
        const sub = (p.m ? Math.round(p.m) + ' min - ' : '') + p.c + (p.c === 1 ? ' övning' : ' övningar')
        ui.button(y, px(96), p.n + '\n' + sub, () => push({ url: 'page/pass', params: JSON.stringify({ id: p.id, n: p.n }) }), {
          color: TILE,
          press: TILE_PRESS,
          size: px(26)
        })
        y += px(108)
      })

      y += px(8)
      ui.button(y, px(72), this.state.loading ? 'Hämtar...' : 'Uppdatera', () => this.refresh(), {
        color: TILE,
        press: TILE_PRESS,
        size: px(24)
      })
      // Luft längst ned så att sista knappen går att nå på en rund skärm.
      ui.text(y + px(72), Math.round(H * 0.25), '')
    }
  })
)
