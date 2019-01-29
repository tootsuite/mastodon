export default function uuid(a?: string): string {
  return a ? ((a as any as number) ^ Math.random() * 16 >> (a as any as number) / 4).toString(16) : (""+1e7+-1e3+-4e3+-8e3+-1e11).replace(/[018]/g, uuid);
};
