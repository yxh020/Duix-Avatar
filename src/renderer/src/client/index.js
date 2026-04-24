
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
    }
  },
  app: {
    ...window.client.app
  }
}