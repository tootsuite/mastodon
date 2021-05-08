interface MastodonMap<T> {
  get<K extends keyof T>(key: K): T[K];
  has<K extends keyof T>(key: K): boolean;
  set<K extends keyof T>(key: K, value: T[K]): this;
}

type AccountValues = {
  id: number;
  avatar: string;
  avatar_static: string;
  [key: string]: any;
}
export type Account = MastodonMap<AccountValues>
