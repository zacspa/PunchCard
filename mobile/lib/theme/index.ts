import { useTheme } from "react-native-paper";
import { getTokens, type PCTokens } from "./tokens";

export { getTokens, palette, radii, spacing, fonts } from "./tokens";
export type { PCTokens, PCScheme } from "./tokens";
export { lightPaperTheme, darkPaperTheme, buildPaperTheme } from "./paper";

export const useTokens = (): PCTokens => {
  const theme = useTheme();
  return getTokens(theme.dark ? "dark" : "light");
};
