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

type HashtagHistoryValues = {
  accounts: number
  uses: number
}

type HashtagValues = {
  url: string;
  name: string;
  history: MastodonMap<HashtagHistoryValues>[]
}
export type Hashtag = MastodonMap<HashtagValues>
