use super::super::{Benchmark, INPUT};

struct TreeNode {
    left: Option<Box<TreeNode>>,
    right: Option<Box<TreeNode>>,
    item: i32,
}

impl TreeNode {
    fn create(item: i32, depth: i32) -> Box<TreeNode> {
        Box::new(TreeNode::new(item, depth - 1))
    }

    fn new(item: i32, depth: i32) -> Self {
        let (left, right) = if depth > 0 {
            (
                Some(TreeNode::new(2 * item - 1, depth - 1)),
                Some(TreeNode::new(2 * item, depth - 1)),
            )
        } else {
            (None, None)
        };

        Self {
            left: left.map(Box::new),
            right: right.map(Box::new),
            item,
        }
    }

    fn check(&self) -> i32 {
        match (&self.left, &self.right) {
            (None, None) => self.item,
            (Some(left), Some(right)) => left.check() - right.check() + self.item,
            _ => self.item,
        }
    }
}

pub struct Binarytrees {
    n: i32,
    result: i64,
}

impl Binarytrees {
    pub fn new() -> Self {
        let name = "Binarytrees".to_string();
        let iterations: i32 = INPUT.get()
            .unwrap()
            .get(&name)
            .and_then(|s| s.parse().ok())
            .unwrap_or(0);
        
        Self {
            n: iterations,
            result: 0,
        }
    }
}

impl Benchmark for Binarytrees {
    fn name(&self) -> String {
        "Binarytrees".to_string()
    }
    
    fn iterations(&self) -> i32 {
        self.n
    }
    
    fn run(&mut self) {
        let min_depth = 4;
        let max_depth = std::cmp::max(min_depth + 2, self.n);
        let stretch_depth = max_depth + 1;
        
        self.result += TreeNode::create(0, stretch_depth).check() as i64;

        let mut depth = min_depth;
        while depth <= max_depth {
            let iterations = 1 << (max_depth - depth + min_depth);
            let mut i = 1;
            while i <= iterations {
                self.result += TreeNode::create(i, depth).check() as i64;
                self.result += TreeNode::create(-i, depth).check() as i64;
                i += 1;
            }
            depth += 2;
        }
    }
    
    fn result(&self) -> i64 {
        self.result
    }
}