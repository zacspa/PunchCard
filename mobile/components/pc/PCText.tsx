import { Text, type TextProps, type TextStyle } from "react-native";
import { useTokens } from "@/lib/theme";

type Variant =
  | "displayXL"
  | "displayL"
  | "displayM"
  | "headline"
  | "title"
  | "body"
  | "bodyStrong"
  | "supporting"
  | "caption"
  | "overline"
  | "mono"
  | "monoSmall"
  | "monoLarge";

type PCTextProps = TextProps & {
  variant?: Variant;
  tone?: "primary" | "secondary" | "tertiary" | "disabled" | "accent" | "rust" | "olive" | "mustard" | "inherit";
  style?: TextStyle | TextStyle[];
};

export const PCText = ({ variant = "body", tone = "primary", style, ...rest }: PCTextProps) => {
  const t = useTokens();
  const v = variantStyles(variant, t);
  const c = toneColor(tone, t);
  return <Text {...rest} style={[v, { color: c }, style as TextStyle]} />;
};

const variantStyles = (v: Variant, t: ReturnType<typeof useTokens>): TextStyle => {
  switch (v) {
    case "displayXL":
      return { fontFamily: t.fonts.display, fontSize: 56, lineHeight: 62, letterSpacing: -1.4 };
    case "displayL":
      return { fontFamily: t.fonts.display, fontSize: 44, lineHeight: 50, letterSpacing: -0.9 };
    case "displayM":
      return { fontFamily: t.fonts.display, fontSize: 30, lineHeight: 36, letterSpacing: -0.3 };
    case "headline":
      return { fontFamily: t.fonts.display, fontSize: 22, lineHeight: 28, letterSpacing: -0.2 };
    case "title":
      return { fontFamily: t.fonts.bodySemi, fontSize: 17, lineHeight: 22 };
    case "body":
      return { fontFamily: t.fonts.body, fontSize: 15, lineHeight: 21 };
    case "bodyStrong":
      return { fontFamily: t.fonts.bodySemi, fontSize: 15, lineHeight: 21 };
    case "supporting":
      return { fontFamily: t.fonts.body, fontSize: 13, lineHeight: 18 };
    case "caption":
      return { fontFamily: t.fonts.body, fontSize: 12, lineHeight: 16 };
    case "overline":
      return {
        fontFamily: t.fonts.bodySemi,
        fontSize: 11,
        lineHeight: 14,
        letterSpacing: 1.3,
        textTransform: "uppercase",
      };
    case "mono":
      return { fontFamily: t.fonts.mono, fontSize: 14, lineHeight: 18 };
    case "monoSmall":
      return { fontFamily: t.fonts.monoRegular, fontSize: 12, lineHeight: 16 };
    case "monoLarge":
      return { fontFamily: t.fonts.monoSemi, fontSize: 16, lineHeight: 22 };
  }
};

const toneColor = (tone: NonNullable<PCTextProps["tone"]>, t: ReturnType<typeof useTokens>): string | undefined => {
  switch (tone) {
    case "primary":
      return t.palette.ink900;
    case "secondary":
      return t.palette.ink700;
    case "tertiary":
      return t.palette.ink500;
    case "disabled":
      return t.palette.ink300;
    case "accent":
      return t.palette.teal600;
    case "rust":
      return t.palette.rust600;
    case "olive":
      return t.palette.olive600;
    case "mustard":
      return t.palette.mustard600;
    case "inherit":
      return undefined;
  }
};
