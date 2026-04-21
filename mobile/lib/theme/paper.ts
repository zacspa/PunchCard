import { MD3DarkTheme, MD3LightTheme, configureFonts, type MD3Theme } from "react-native-paper";
import { fonts, palette, type PCScheme } from "./tokens";

const buildFontConfig = () => {
  const base = {
    fontFamily: fonts.body,
    fontWeight: "400" as const,
    letterSpacing: 0,
  };
  return configureFonts({
    config: {
      displayLarge: { ...base, fontFamily: fonts.displayBold, fontSize: 44, lineHeight: 50, letterSpacing: -0.5 },
      displayMedium: { ...base, fontFamily: fonts.display, fontSize: 34, lineHeight: 40, letterSpacing: -0.3 },
      displaySmall: { ...base, fontFamily: fonts.display, fontSize: 28, lineHeight: 34, letterSpacing: -0.2 },
      headlineLarge: { ...base, fontFamily: fonts.display, fontSize: 26, lineHeight: 32, letterSpacing: -0.2 },
      headlineMedium: { ...base, fontFamily: fonts.display, fontSize: 22, lineHeight: 28, letterSpacing: -0.1 },
      headlineSmall: { ...base, fontFamily: fonts.display, fontSize: 20, lineHeight: 26, letterSpacing: -0.1 },
      titleLarge: { ...base, fontFamily: fonts.bodySemi, fontSize: 17, lineHeight: 22 },
      titleMedium: { ...base, fontFamily: fonts.bodySemi, fontSize: 15, lineHeight: 20 },
      titleSmall: { ...base, fontFamily: fonts.bodyMedium, fontSize: 13, lineHeight: 18 },
      labelLarge: { ...base, fontFamily: fonts.bodyMedium, fontSize: 14, lineHeight: 18 },
      labelMedium: { ...base, fontFamily: fonts.bodyMedium, fontSize: 12, lineHeight: 16 },
      labelSmall: { ...base, fontFamily: fonts.bodySemi, fontSize: 11, lineHeight: 14, letterSpacing: 1.1 },
      bodyLarge: { ...base, fontSize: 16, lineHeight: 22 },
      bodyMedium: { ...base, fontSize: 15, lineHeight: 20 },
      bodySmall: { ...base, fontSize: 13, lineHeight: 18 },
    },
  });
};

export const buildPaperTheme = (scheme: PCScheme): MD3Theme => {
  const p = palette[scheme];
  const base = scheme === "dark" ? MD3DarkTheme : MD3LightTheme;
  return {
    ...base,
    dark: scheme === "dark",
    roundness: 14,
    fonts: buildFontConfig(),
    colors: {
      ...base.colors,
      primary: p.teal600,
      onPrimary: p.cream50,
      primaryContainer: p.teal100,
      onPrimaryContainer: p.ink900,
      secondary: p.olive600,
      onSecondary: p.cream50,
      secondaryContainer: p.olive100,
      onSecondaryContainer: p.ink900,
      tertiary: p.mustard600,
      onTertiary: p.ink900,
      tertiaryContainer: p.mustard100,
      onTertiaryContainer: p.ink900,
      error: p.red600,
      onError: p.cream50,
      errorContainer: p.rust100,
      onErrorContainer: p.ink900,
      background: p.cream50,
      onBackground: p.ink900,
      surface: p.cream100,
      onSurface: p.ink900,
      surfaceVariant: p.cream100,
      onSurfaceVariant: p.ink700,
      surfaceDisabled: p.cream200,
      onSurfaceDisabled: p.ink300,
      outline: p.cream300,
      outlineVariant: p.cream200,
      inverseSurface: p.ink900,
      inverseOnSurface: p.cream50,
      inversePrimary: p.teal500,
      shadow: scheme === "dark" ? "rgba(0,0,0,0.5)" : "rgba(42,36,24,0.15)",
      scrim: "rgba(0,0,0,0.45)",
      backdrop: "rgba(0,0,0,0.35)",
      elevation: {
        level0: "transparent",
        level1: p.cream100,
        level2: p.cream100,
        level3: p.cream100,
        level4: p.cream100,
        level5: p.cream100,
      },
    },
  };
};

export const lightPaperTheme = buildPaperTheme("light");
export const darkPaperTheme = buildPaperTheme("dark");
