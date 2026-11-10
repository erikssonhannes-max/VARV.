import { createWidget, deleteWidget, widget, align, text_style, prop } from '@zos/ui'
import { getDeviceInfo } from '@zos/device'
import { px } from '@zos/utils'

// VARV.:s färger, samma som i appen i mörkt tema.
export const ACCENT = 0xff2d55
export const ACCENT_PRESS = 0xc81e40
export const GREEN = 0x30d158
export const WHITE = 0xffffff
export const MUTED = 0x9a9aa3
export const TILE = 0x232327
export const TILE_PRESS = 0x34343a

const info = getDeviceInfo()
export const W = info.width
export const H = info.height
// Runda skärmar behöver mer luft i kanterna.
const round = Math.abs(W - H) < 4
export const PAD = round ? Math.round(W * 0.12) : px(16)
export const INNER = W - PAD * 2

// Håller reda på vyns delar, så att vyn kan ritas om från början.
export function canvas() {
  let parts = []
  return {
    clear() {
      parts.forEach((p) => {
        try {
          deleteWidget(p)
        } catch (e) {}
      })
      parts = []
    },
    text(y, h, text, opts = {}) {
      const w = createWidget(widget.TEXT, {
        x: opts.x != null ? opts.x : PAD,
        y,
        w: opts.w || INNER,
        h,
        text: String(text == null ? '' : text),
        color: opts.color != null ? opts.color : WHITE,
        text_size: opts.size || px(28),
        align_h: opts.left ? align.LEFT : align.CENTER_H,
        align_v: align.CENTER_V,
        text_style: opts.nowrap ? text_style.ELLIPSIS : text_style.WRAP
      })
      parts.push(w)
      return w
    },
    button(y, h, text, onClick, opts = {}) {
      const b = createWidget(widget.BUTTON, {
        x: opts.x != null ? opts.x : PAD,
        y,
        w: opts.w || INNER,
        h,
        radius: Math.round(h / 2),
        normal_color: opts.color != null ? opts.color : ACCENT,
        press_color: opts.press != null ? opts.press : ACCENT_PRESS,
        text: String(text),
        text_size: opts.size || px(28),
        color: WHITE,
        click_func: () => onClick()
      })
      parts.push(b)
      return b
    }
  }
}

export function setText(w, text) {
  try {
    w.setProperty(prop.TEXT, String(text))
  } catch (e) {}
}
