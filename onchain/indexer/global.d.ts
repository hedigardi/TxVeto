declare module "ponder:registry" {
  export const ponder: {
    on: (
      eventName: string,
      handler: (ctx: any) => Promise<void> | void,
    ) => void;
  };
}
