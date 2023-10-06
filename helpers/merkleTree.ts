import type { PoseidonHasher } from "./utils";

export type KV = { key: string; value: any }

export class JsStorage {
  db!: Record<any, any>
  constructor(db = {}) {
    this.db = db;
  }

  get(key: string) {
    return this.db[key] as string | undefined;
  }

  get_or_element<T>(key: string, defaultElement: T) {
    const element: T = this.db[key];
    if (element === undefined) {
      return defaultElement;
    } else {
      return element;
    }
  }

  put<T>(key: string, value: T) {
    if (key === undefined || value === undefined) {
      throw Error("key or value is undefined");
    }
    this.db[key] = value;
  }

  del(key: string) {
    delete this.db[key];
  }

  async put_batch(key_values: KV[]) {
    key_values.forEach((element) => {
      this.db[element.key] = element.value;
    });
  }
}

export class MerkleTree {
  zero_values!: string[];
  totalElements = 0;
  hasher!: PoseidonHasher;
  storage!: JsStorage;
  prefix!: string;
  n_levels!: number;

  constructor(n_levels: number, prefix: string, hasher: PoseidonHasher, storage = new JsStorage()) {
    this.zero_values = [];
    this.totalElements = 0;
    this.hasher = hasher;
    this.storage = storage;
    this.prefix = prefix;
    this.n_levels = n_levels;

    let current_zero_value =
      "21663839004416932945382355908790599225266501822907911457504978515578255421292";
    this.zero_values.push(current_zero_value);
    for (let i = 0; i < n_levels; i++) {
      current_zero_value = this.hasher.hash(
        current_zero_value,
        current_zero_value
      );
      this.zero_values.push(current_zero_value.toString());
    }
  }

  static index_to_key(prefix: string, level: number, index: number) {
    const key = `${prefix}_tree_${level}_${index}`;
    return key;
  }

  async root() {
    let root = await this.storage.get_or_element<string>(
      MerkleTree.index_to_key(this.prefix, this.n_levels, 0),
      this.zero_values[this.n_levels]
    );

    return root;
  }

  async path(index: number) {
    class PathTraverser {
      path_elements!: string[];
      path_index!: number[];
      prefix!: string;
      storage!: JsStorage
      zero_values!: string[]
      constructor(prefix: string, storage: JsStorage, zero_values: string[]) {
        this.path_elements = [];
        this.path_index = [];
        this.prefix = prefix;
        this.storage = storage;
        this.zero_values = zero_values;
      }

      async handle_index(level: number, element_index: number, sibling_index: number) {
        const sibling = await this.storage.get_or_element(
          MerkleTree.index_to_key(this.prefix, level, sibling_index),
          this.zero_values[level]
        );
        this.path_elements.push(sibling);
        this.path_index.push(element_index % 2);
      }
    }
    index = Number(index);
    let traverser = new PathTraverser(
      this.prefix,
      this.storage,
      this.zero_values
    );
    const root = await this.storage.get_or_element(
      MerkleTree.index_to_key(this.prefix, this.n_levels, 0),
      this.zero_values[this.n_levels]
    );

    const element = await this.storage.get_or_element(
      MerkleTree.index_to_key(this.prefix, 0, index),
      this.zero_values[0]
    );

    await this.traverse(index, traverser);
    return {
      root,
      path_elements: traverser.path_elements,
      path_index: traverser.path_index,
      element,
    };
  }

  async update(index: number, element, insert = false) {
    if (!insert && index >= this.totalElements) {
      throw Error("Use insert method for new elements.");
    } else if (insert && index < this.totalElements) {
      throw Error("Use update method for existing elements.");
    }
    try {
      class UpdateTraverser {
        key_values_to_put!: KV[];
        original_element = "";
        prefix!: string;
        storage!: JsStorage
        hasher!: PoseidonHasher
        current_element!: string
        zero_values!: string[]
        constructor(prefix: string, storage: JsStorage, hasher: PoseidonHasher, current_element: string, zero_values: string[]) {
          this.key_values_to_put = [];
          this.prefix = prefix;
          this.storage = storage;
          this.hasher = hasher;
          this.current_element = current_element;
          this.zero_values = zero_values;
        }

        async handle_index(level: number, element_index: number, sibling_index: number) {
          if (level == 0) {
            this.original_element = await this.storage.get_or_element(
              MerkleTree.index_to_key(this.prefix, level, element_index),
              this.zero_values[level]
            );
          }
          const sibling = await this.storage.get_or_element(
            MerkleTree.index_to_key(this.prefix, level, sibling_index),
            this.zero_values[level]
          );
          let left!: string
          let right!: string
          if (element_index % 2 == 0) {
            left = this.current_element;
            right = sibling;
          } else {
            left = sibling;
            right = this.current_element;
          }

          this.key_values_to_put.push({
            key: MerkleTree.index_to_key(this.prefix, level, element_index),
            value: this.current_element,
          });
          this.current_element = this.hasher.hash(left, right);
        }
      }
      let traverser = new UpdateTraverser(
        this.prefix,
        this.storage,
        this.hasher,
        element,
        this.zero_values
      );

      await this.traverse(index, traverser);
      traverser.key_values_to_put.push({
        key: MerkleTree.index_to_key(this.prefix, this.n_levels, 0),
        value: traverser.current_element,
      });

      await this.storage.put_batch(traverser.key_values_to_put);
    } catch (e) {
      console.error(e);
    }
  }

  async getTopTwoElements() {
    const sibling0 = await this.storage.get_or_element<string>(
      MerkleTree.index_to_key(this.prefix, 19, 0),
      this.zero_values[19]
    );
    const sibling1 = await this.storage.get_or_element<string>(
      MerkleTree.index_to_key(this.prefix, 19, 1),
      this.zero_values[19]
    );

    return [sibling0, sibling1];
  }

  async insert(element) {
    const index = this.totalElements;
    await this.update(index, element, true);
    this.totalElements++;
  }

  async traverse(index, handler) {
    let current_index = index;
    for (let i = 0; i < this.n_levels; i++) {
      let sibling_index = current_index;
      if (current_index % 2 == 0) {
        sibling_index += 1;
      } else {
        sibling_index -= 1;
      }
      await handler.handle_index(i, current_index, sibling_index);
      current_index = Math.floor(current_index / 2);
    }
  }

  getIndexByElement(element: string) {
    for (let i = this.totalElements - 1; i >= 0; i--) {
      const elementFromTree = this.storage.get(
        MerkleTree.index_to_key(this.prefix, 0, i)
      );
      if (elementFromTree === element) {
        return i;
      }
    }
    return false;
  }
}
