use super::super::config_i64;
use super::super::Benchmark;

struct TreeNode {
    left: Option<Box<TreeNode>>,
    right: Option<Box<TreeNode>>,
    item: i32,
}

impl TreeNode {
    fn new(item: i32, depth: i32) -> Self {
        if depth > 0 {
            let left = Box::new(TreeNode::new(item - (1 << (depth - 1)), depth - 1));
            let right = Box::new(TreeNode::new(item + (1 << (depth - 1)), depth - 1));

            Self {
                left: Some(left),
                right: Some(right),
                item,
            }
        } else {
            Self {
                left: None,
                right: None,
                item,
            }
        }
    }

    fn sum(&self) -> u32 {
        let mut total = (self.item as u32).wrapping_add(1);

        if let Some(left) = &self.left {
            total = total.wrapping_add(left.sum());
        }
        if let Some(right) = &self.right {
            total = total.wrapping_add(right.sum());
        }

        total
    }
}

pub struct BinarytreesObj {
    n: i64,
    result_val: u32,
}

impl BinarytreesObj {
    pub fn new() -> Self {
        let n = config_i64("Binarytrees::Obj", "depth");
        Self { n, result_val: 0 }
    }
}

impl Benchmark for BinarytreesObj {
    fn name(&self) -> String {
        "Binarytrees::Obj".to_string()
    }

    fn run(&mut self, _iteration_id: i64) {
        let root = Box::new(TreeNode::new(0, self.n as i32));
        self.result_val = self.result_val.wrapping_add(root.sum());
    }

    fn checksum(&self) -> u32 {
        self.result_val
    }
}

struct TreeNodeArena {
    item: i32,
    left: i32,
    right: i32,
}

impl TreeNodeArena {
    fn new(item: i32) -> Self {
        Self {
            item,
            left: -1,
            right: -1,
        }
    }
}

pub struct BinarytreesArena {
    arena: Vec<TreeNodeArena>,
    n: i64,
    result_val: u32,
}

impl BinarytreesArena {
    pub fn new() -> Self {
        let n = config_i64("Binarytrees::Arena", "depth");
        Self {
            arena: Vec::new(),
            n,
            result_val: 0,
        }
    }

    fn build_tree(&mut self, item: i32, depth: i32) -> i32 {
        let idx = self.arena.len() as i32;
        self.arena.push(TreeNodeArena::new(item));

        if depth > 0 {
            let left_idx = self.build_tree(item - (1 << (depth - 1)), depth - 1);
            let right_idx = self.build_tree(item + (1 << (depth - 1)), depth - 1);

            if let Some(node) = self.arena.get_mut(idx as usize) {
                node.left = left_idx;
                node.right = right_idx;
            }
        }

        idx
    }

    fn sum(&self, idx: i32) -> u32 {
        let node = &self.arena[idx as usize];
        let mut total = (node.item as u32).wrapping_add(1);

        if node.left >= 0 {
            total = total.wrapping_add(self.sum(node.left));
        }
        if node.right >= 0 {
            total = total.wrapping_add(self.sum(node.right));
        }

        total
    }
}

impl Benchmark for BinarytreesArena {
    fn name(&self) -> String {
        "Binarytrees::Arena".to_string()
    }

    fn run(&mut self, _iteration_id: i64) {
        self.arena = Vec::new();
        self.build_tree(0, self.n as i32);
        self.result_val = self.result_val.wrapping_add(self.sum(0));
    }

    fn checksum(&self) -> u32 {
        self.result_val
    }
}
