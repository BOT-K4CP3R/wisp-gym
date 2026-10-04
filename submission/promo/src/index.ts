import { registerRoot, staticFile } from "remotion";
import { loadFont } from "@remotion/fonts";
import { Root } from "./Root";

// The app's own typeface (entry/src/main/resources/rawfile/fonts).
loadFont({ family: "Nunito", url: staticFile("Nunito-Medium.ttf"), weight: "500" });
loadFont({ family: "Nunito", url: staticFile("Nunito-ExtraBold.ttf"), weight: "800" });

registerRoot(Root);
