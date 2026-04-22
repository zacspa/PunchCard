import { Directory, File, Paths } from "expo-file-system";

const RECEIPTS_DIRNAME = "receipts";

const ensureDir = (): Directory => {
  const dir = new Directory(Paths.document, RECEIPTS_DIRNAME);
  if (!dir.exists) dir.create({ intermediates: true });
  return dir;
};

/**
 * Persist a captured image URI (typically from expo-camera's cache) into the
 * document directory, so it survives OS cache eviction. Returns the new URI.
 */
export const persistReceiptImage = (sourceURI: string, expenseId: string): string => {
  const dir = ensureDir();
  const src = new File(sourceURI);
  const ext = src.extension || ".jpg";
  const dest = new File(dir, `${expenseId}${ext}`);
  if (dest.exists) dest.delete();
  src.copy(dest);
  return dest.uri;
};
