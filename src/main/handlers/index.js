import { ipcMain } from "electron"
import file from './file'
import app from './app'
import serverConfig from './serverConfig'


const handles = [file, app, serverConfig]

export const registerWebHandles = (app) => {

  for (const handle of handles) {
    for (const key of Object.keys(handle)) {
      if (typeof handle[key] == 'function') {
        //方法暴露给前端
        ipcMain.handle(`${handle.name}.${key}`, (event, ...args) => {
          app.event = event
          return handle[key](app, ...args)
        })
      }
    }
  }
}

export const exposeWebHandles = (electronAPI) => {
  const api = {}
  for (const handle of handles) {
    api[handle.name] = {}
    for (const key of Object.keys(handle)) {
      if (typeof handle[key] == 'function') {
        api[handle.name][key] = (...args) => electronAPI.ipcRenderer.invoke(`${handle.name}.${key}`, ...args)
      }
    }

  }
  return api
}