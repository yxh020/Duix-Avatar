
export const Client = {
  file: {
    ...window.client.file,
    selectFile: (filter = {}) => {
      return window.client.file.selectFile(filter)
    },
    selectImage: async () => {
      return Client.file.selectFile({ name: 'Images', extensions: ['jpg', 'png', 'jpeg'] })
    },
    selectVideo: async (multiSelections = false) => {
      return Client.file.selectFile({ name: 'Videos', extensions: ['mp4', 'mov'], multiSelections })
    },
    selectAudio: async (multiSelections = false) => {
      return Client.file.selectFile({ name: 'Audios', extensions: ['mp3', 'wav', 'flac', 'm4a'], multiSelections })
    },
    selectFolder: async () => {
      return window.client.file.selectFolder()
    },
    deleteFile: async (filePath) => {
      return window.client.file.deleteFile(filePath)
    }
  },
  app: {
    ...window.client.app
  },
  serverConfig: {
    ...window.client.serverConfig
  }
}