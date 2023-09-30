class JsStorage {
  constructor(db = {}) {
    this.db = db;
  }

  get(key) {
    return this.db[key];
  }

  get_or_element(key, defaultElement) {
    const element = this.db[key];
    if (element === undefined) {
      return defaultElement;
    } else {
      return element;
    }
  }

  put(key, value) {
    if (key === undefined || value === undefined) {
      throw Error("key or value is undefined");
    }
    this.db[key] = value;
  }

  del(key) {
    delete this.db[key];
  }

  put_batch(key_values) {
    key_values.forEach((element) => {
      this.db[element.key] = element.value;
    });
  }
}

// export interface Hasher {
//     hash(left, right);
// }

// interface Handler {
//     handle_index(i, current_index, sibling_index): void;
// }

class MerkleTree {
  zero_values;
  totalElements;

  constructor(n_levels, prefix, hasher, storage = new JsStorage()) {
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

  static index_to_key(prefix, level, index) {
    const key = `${prefix}_tree_${level}_${index}`;
    return key;
  }

  async root() {
    let root = await this.storage.get_or_element(
      MerkleTree.index_to_key(this.prefix, this.n_levels, 0),
      this.zero_values[this.n_levels]
    );

    return root;
  }

  async path(index) {
    class PathTraverser {
      path_elements;
      path_index;
      constructor(prefix, storage, zero_values) {
        this.path_elements = [];
        this.path_index = [];
        this.prefix = prefix;
        this.storage = storage;
        this.zero_values = zero_values;
      }

      async handle_index(level, element_index, sibling_index) {
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

  async update(index, element, insert = false) {
    if (!insert && index >= this.totalElements) {
      throw Error("Use insert method for new elements.");
    } else if (insert && index < this.totalElements) {
      throw Error("Use update method for existing elements.");
    }
    try {
      class UpdateTraverser {
        key_values_to_put;
        original_element = "";
        constructor(prefix, storage, hasher, current_element, zero_values) {
          this.key_values_to_put = [];
          this.prefix = prefix;
          this.storage = storage;
          this.hasher = hasher;
          this.current_element = current_element;
          this.zero_values = zero_values;
        }

        async handle_index(level, element_index, sibling_index) {
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
          let left, right;
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
    const sibling0 = await this.storage.get_or_element(
      MerkleTree.index_to_key(this.prefix, 19, 0),
      this.zero_values[19]
    );
    const sibling1 = await this.storage.get_or_element(
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

  getIndexByElement(element) {
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

module.exports = {
  MerkleTree,
};
