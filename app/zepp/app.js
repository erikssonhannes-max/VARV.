import { BaseApp } from '@zeppos/zml/base-app'

// VARV. på Amazfit. Allt som rör kontot sköts av sidotjänsten i appen Zepp på telefonen (app-side/index.js).
App(BaseApp({
  globalData: {},
  onCreate() {},
  onDestroy() {}
}))
