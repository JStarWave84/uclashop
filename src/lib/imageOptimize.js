import imageCompression from 'browser-image-compression'

const PRODUCT_IMG = {
  maxSizeMB: 0.5,
  maxWidthOrHeight: 1600,
  initialQuality: 0.8,
  useWebWorker: true,
  fileType: 'image/webp',
}

const LOGO_IMG = {
  maxSizeMB: 0.1,
  maxWidthOrHeight: 512,
  initialQuality: 0.85,
  useWebWorker: true,
  fileType: 'image/webp',
}

const RECEIPT_IMG = {
  maxSizeMB: 1,
  maxWidthOrHeight: 2048,
  initialQuality: 0.85,
  useWebWorker: true,
  fileType: 'image/webp',
}

async function optimize(file, options) {
  try {
    return await imageCompression(file, options)
  } catch (e) {
    console.error('optimizeImage', e)
    return file
  }
}

export const optimizeProductImage = (file) => optimize(file, PRODUCT_IMG)
export const optimizeLogoImage = (file) => optimize(file, LOGO_IMG)
export const optimizeReceiptImage = (file) => optimize(file, RECEIPT_IMG)
