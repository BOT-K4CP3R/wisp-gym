import React from "react";
import { Composition } from "remotion";
import { Promo, totalSeconds } from "./Promo";

const FPS = 30;

export const Root: React.FC = () => (
  <Composition id="WispPromo" component={Promo} durationInFrames={Math.round(totalSeconds * FPS)} fps={FPS} width={1920} height={1080} />
);
