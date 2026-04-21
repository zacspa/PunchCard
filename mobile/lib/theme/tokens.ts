export type PCScheme = "light" | "dark";

type PCPalette = {
  cream50: string;
  cream100: string;
  cream200: string;
  cream300: string;
  ink900: string;
  ink700: string;
  ink500: string;
  ink300: string;
  teal600: string;
  teal500: string;
  teal100: string;
  teal50: string;
  rust600: string;
  rust500: string;
  rust100: string;
  olive600: string;
  olive100: string;
  mustard600: string;
  mustard100: string;
  green600: string;
  red600: string;
};

const lightPalette: PCPalette = {
  cream50: "#fbf5e9",
  cream100: "#f5ecd7",
  cream200: "#ece0be",
  cream300: "#ddd0a6",
  ink900: "#2a2418",
  ink700: "#5a4e36",
  ink500: "#8a7b5a",
  ink300: "#b9ab87",
  teal600: "#1f6f6b",
  teal500: "#2a8782",
  teal100: "#c7e1dd",
  teal50: "#e4f0ed",
  rust600: "#b44a2a",
  rust500: "#c96442",
  rust100: "#ecd0c1",
  olive600: "#6e6a2c",
  olive100: "#dcd9a8",
  mustard600: "#b98a1d",
  mustard100: "#efdfa8",
  green600: "#4f7a2c",
  red600: "#a53a2a",
};

const darkPalette: PCPalette = {
  cream50: "#1a1712",
  cream100: "#242018",
  cream200: "#322c20",
  cream300: "#4a412e",
  ink900: "#f2e8d0",
  ink700: "#bfae85",
  ink500: "#8e7f5e",
  ink300: "#5a5140",
  teal600: "#6bbfb3",
  teal500: "#8dd2c7",
  teal100: "#234340",
  teal50: "#1d322f",
  rust600: "#e08966",
  rust500: "#eba082",
  rust100: "#4a2a1c",
  olive600: "#b9b36f",
  olive100: "#3d3a20",
  mustard600: "#dcb658",
  mustard100: "#453820",
  green600: "#8fc366",
  red600: "#e08066",
};

export const palette = { light: lightPalette, dark: darkPalette };

export const radii = {
  xs: 4,
  sm: 8,
  md: 14,
  lg: 22,
  xl: 28,
} as const;

export const spacing = {
  xs: 4,
  sm: 8,
  md: 12,
  lg: 16,
  xl: 20,
  "2xl": 24,
  "3xl": 28,
} as const;

export const fonts = {
  display: "Fraunces_600SemiBold",
  displayBold: "Fraunces_700Bold",
  displayMedium: "Fraunces_500Medium",
  body: "Inter_400Regular",
  bodyMedium: "Inter_500Medium",
  bodySemi: "Inter_600SemiBold",
  bodyBold: "Inter_700Bold",
  mono: "JetBrainsMono_500Medium",
  monoSemi: "JetBrainsMono_600SemiBold",
  monoRegular: "JetBrainsMono_400Regular",
} as const;

export type PCTokens = {
  scheme: PCScheme;
  palette: PCPalette;
  radii: typeof radii;
  spacing: typeof spacing;
  fonts: typeof fonts;
};

export const getTokens = (scheme: PCScheme): PCTokens => ({
  scheme,
  palette: palette[scheme],
  radii,
  spacing,
  fonts,
});
