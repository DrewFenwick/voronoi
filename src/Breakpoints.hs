module Breakpoints 
  ( Tree (..)
  , BTree (..)
  , Breakpoint (..)
  , inOrderSuccessor
  , inOrderPredecessor
  , insertPair
  , joinPairAt
  , updateBreakpoint
  , inorder
  )
where


import Debug.Trace

import qualified Data.Vector.Unboxed as V

import Control.Arrow ((***))


type Index = Int
type Point a = (a, a)

type Breakpoint = (Index, Index)


--data Tree a = Leaf a | Branch (Tree a) (Tree a) deriving Show
data Tree a = Nil | Node (Tree a) a (Tree a) deriving Show

instance Foldable Tree where
  foldMap f Nil = mempty
  foldMap f (Node Nil x Nil) = f x
  foldMap f (Node l k r) = foldMap f l `mappend` f k `mappend` foldMap f r

  foldr f z Nil = z
  foldr f z (Node Nil x Nil) = f x z
  foldr f z (Node l k r) = foldr f (f k (foldr f z r)) l

type BTree = Tree (Int, Breakpoint)


nilEnd x = Node Nil x Nil



-- helper, draw tree:
drawTree :: BTree -> String
drawTree = unlines . draw

{-
draw :: (Show a) => BTree a -> [String]
draw (Leaf b) = [show b]
draw (Branch l r) =  "" : drawSubTrees [l, r]
  where
    drawSubTrees [] = []
    drawSubTrees [t] =
      "|" : shift "`- " "   " (draw t)
    drawSubTrees (t:ts) =
      "|" : shift "+- " "|  " (draw t) ++ drawSubTrees ts
    shift first other = zipWith (++) (first : repeat other)
-}

draw :: BTree -> [String]
draw Nil = ["Nil"]
draw (Node l x r) =  (show x) : drawSubTrees [l, r]
  where
    drawSubTrees [] = []
    drawSubTrees [t] =
      "|" : shift "`- " "   " (draw t)
    drawSubTrees (t:ts) =
      "|" : shift "+- " "|  " (draw t) ++ drawSubTrees ts
    shift first other = zipWith (++) (first : repeat other)

inorder :: Tree a -> [a]
inorder Nil = []
inorder (Node t1 v t2) = inorder t1 ++ [v] ++ inorder t2


-- TODO: Insert, Delete, !!, merge, fmap


-- | 'evalParabola focus directrix x' evaluates the parabola defined by the
-- focus and directrix at x
evalParabola :: (Show a, Floating a) => Point a -> a -> a -> a
evalParabola (fx, fy) d x = (fx*fx-2*fx*x+fy*fy-d*d+x*x)/(2*fy-2*d)

{- |
    > intersection f1 f2 d
    Find the intersection between the parabolas with focus /f1/ and /f2/ and
    directrix /d/.
-}
intersection :: (Show a, Floating a) 
             => Point a -> Point a -> a -> a
intersection (f1x, f1y) (f2x, f2y) d =
  let
    dist = (f1x - f2x) * (f1x - f2x) + (f1y - f2y) * (f1y-f2y)
    sqroot = sqrt $ dist * (f1y - d) * (f2y - d)
    lastterm = f1x * (d - f2y) - f2x * d
    --x1 = (f1y*f2x - sqroot + lastterm)/(f1y - f2y)
    x = (f1y*f2x + sqroot + lastterm)/(f1y - f2y)
  in
    x


updateBreakpoint :: (Show a, Floating a, V.Unbox a) => Breakpoint -> V.Vector (Point a) -> a -> a
updateBreakpoint (i, j)  ps d =
  intersection (V.unsafeIndex ps i) (V.unsafeIndex ps j) d


{-
insertPair :: (Show a, Floating a, Ord a, V.Unbox a)
           => a -> Index -> a -> V.Vector (Point a) -> BTree a -> BTree a
insertPair x k d ps (Branch l@(Leaf l') r)
  | updated < x = Branch updated' $ insertPair x k d ps r
  | otherwise = Branch (insertPair x k d ps updated') r
  where
    updated = updateBreakpoint (snd l') ps d 
    updated' = Leaf (updated, snd l')
insertPair x k d ps (Leaf b)
  | updated < x =
    Branch updated' (Branch (Leaf (x, (j ,k))) (Leaf (x, (k, j))))
  | otherwise =
    Branch (Branch (Leaf (x, (i, k))) (Leaf (x, (k, i)))) updated'
  where
    i = fst . snd $ b
    j = snd . snd $ b
    updated = updateBreakpoint (snd b) ps d 
    updated' = Leaf (updated, snd b)

insertBreakpoint :: (Show a, Floating a, Ord a, V.Unbox a)
                 => a -> Breakpoint -> a -> V.Vector (Point a) -> BTree a -> BTree a
insertBreakpoint x break d ps tree = case tree of
  Branch l@(Leaf l') r -> if updateBreakpoint (snd l') ps d < x then
      Branch l $ insertBreakpoint x break d ps r
    else
      Branch (insertBreakpoint x break d ps l) r
  Leaf b -> if updateBreakpoint (snd b) ps d < x then
      Branch (Leaf b) (Leaf (x, break))
    else
      Branch (Leaf (x, break)) (Leaf b)
-}    

ps = V.fromList [(0,0), (5,5), (3,7), (4, 10)] :: V.Vector (Point Double)
root = Node Nil (5, (0, 1)) (Node Nil (5, (1, 0)) Nil)  :: BTree
--root = Branch (Leaf (5, (0,1))) (Leaf (5, (1,0))) :: BTree Float


insert :: (RealFrac a, Show a, Floating a, Ord a, V.Unbox a)
       => a -> Index -> Index -> a -> V.Vector (Point a) -> BTree -> BTree
insert x i j _ _  Nil = Node Nil (floor x, (i, j)) Nil
insert x i j d ps n@(Node l b' r)
  | x < updated = Node (insert x i j d ps l) b r
  | x >= updated = Node l b (insert x i j d ps r)
  where
    b = (floor updated, snd b')
    updated = updateBreakpoint (snd b') ps d


insertPair :: (RealFrac a, Show a, Floating a, Ord a, V.Unbox a)
           => a -> Index -> a -> V.Vector (Point a) -> BTree -> (BTree, (Int, Breakpoint))
insertPair x k d ps (Node Nil b' Nil)
  | x < updated = (Node (Node Nil (x', (i, k)) (nilEnd (x', (k, i)))) b Nil, (i, snd b))
  | otherwise   = (Node Nil b (Node Nil (x', (j, k)) (nilEnd (x', (k, j)))), (j, snd b))
  where
    x' = floor x
    i = fst . snd $ b
    j = snd . snd $ b
    updated = updateBreakpoint (snd b') ps d
    b = (floor updated, snd b')

insertPair x k d ps (Node Nil b' r)
  | x < updated = (Node (Node Nil (x', (i, k)) (nilEnd (x', (k, i)))) b r, (i, snd b))
  | otherwise   = (Node Nil b *** id) $ insertPair x k d ps r
  where
    x' = floor x
    i = fst . snd $ b
    updated = updateBreakpoint (snd b') ps d
    b = (floor updated, snd b')


insertPair x k d ps (Node l b' Nil)
  | x < updated = (flip ((flip Node) b) Nil *** id) $ insertPair x k d ps l
  | otherwise  = (Node l b $ Node  Nil (x', (j, k)) (nilEnd (x', (k, j))), (j, snd b))
  where
    x' = floor x
    j = snd . snd $ b
    updated = updateBreakpoint (snd b') ps d
    b = (floor updated, snd b')

insertPair x k d ps (Node l b' r)
  | x < updated = (flip ((flip Node) b) r *** id) $ insertPair x k d ps l
  | otherwise   = (Node l b *** id) $ insertPair x k d ps r
  where
    updated = updateBreakpoint (snd b') ps d
    b = (floor updated, snd b')

insertPair _ _ _ _ Nil = error "insertPair: Trying to insert in Nil."
{-
insertPair' :: (RealFrac a, Show a, Floating a, Ord a, V.Unbox a)
           => a -> Index -> a -> V.Vector (Point a) -> BTree -> BTree -> (BTree, Int)
insertPair' x k d ps (Node l acc r) (Node Nil b' Nil) = 
  if acc < updated then (Node l acc res, idx) else (Node res acc r, idx)
  where
    x' = floor x
    i = fst . snd $ b
    j = snd . snd $ b
    updated = updateBreakpoint (snd b') ps d
    b = (floor updated, snd b')
    (res, idx)
      | x < updated = (Node (Node Nil (x', (i, k)) (nilEnd (x', (k, i)))) b Nil, i)
      | otherwise   = (Node Nil b (Node Nil (x', (j, k)) (nilEnd (x', (k, j)))), j)

insertPair' x k d ps (Node l acc r') (Node Nil b' r)
  | x < updated = 
  | otherwise = 
-}

lookFor :: (RealFrac a, Show a, Floating a, Ord a, V.Unbox a)
        => a -> Breakpoint -> a -> V.Vector (Point a) -> BTree -> BTree
lookFor _ _ _ _ Nil = Nil -- error "lookFor: reached Nil."
lookFor x break d ps n@(Node l b r)
  | break == (snd b) = n
  | x < updated = lookFor x break d ps l
  | x >= updated = lookFor x break d ps r
  | otherwise = error "lookFor: Breakpoint does not exist."
  where
    updated = updateBreakpoint (snd b) ps d

delete :: (Show a, Floating a, RealFrac a, Ord a, V.Unbox a)
       => a -> Breakpoint -> a -> V.Vector (Point a) -> BTree -> BTree
delete _ _ _ _ Nil = error "delete: reached Nil"
delete x break d ps n@(Node l b r)
  | break == (snd b) = deleteX d ps n
  | x < updated = Node (delete x break d ps l) b r
  | x >= updated = Node l b (delete x break d ps r)
  | otherwise = error "delete: Breakpoint does not exist."
  where
    updated = updateBreakpoint (snd b) ps d

deleteX :: (Show a, Floating a, RealFrac a, Ord a, V.Unbox a)
        => a -> V.Vector (Point a)-> BTree -> BTree
deleteX _ _  (Node Nil v t2) = t2
deleteX _ _  (Node t1 v Nil) = t1
deleteX d ps (Node t1 v t2)  = Node t1 v2 $ delete (updateBreakpoint (snd v2) ps d) (snd v2) d ps t2 --(delete t2 v2))
  where 
    v2 = leftistElement t2


delete2 :: (Show a, Floating a, RealFrac a, Ord a, V.Unbox a)
        => a -> Breakpoint -> a -> Breakpoint -> a -> V.Vector (Point a) -> BTree -> BTree
delete2 _  _  _  _  _ _  Nil = error "delete2: reached Nil"
delete2 x1 b1 x2 b2 d ps n@(Node l b r)
  | b1 == snd b = delete x2 b2 d ps $ deleteX d ps n
  | b2 == snd b = delete x1 b1 d ps $ deleteX d ps n
  | x1 < u && x2 < u =
    Node (delete2 x1 b1 x2 b2 d ps l) b r
  | x1 >= u && x2 >= u =
    Node l b (delete2 x1 b1 x2 b2 d ps r)
  | x1 < u = 
    Node (delete x1 b1 d ps l) b (delete x2 b2 d ps r)
  | otherwise = -- x2 < updated && x1 >= updated
    Node (delete x2 b2 d ps l) b (delete x1 b1 d ps r)
  where
    u = updateBreakpoint (snd b) ps d

-- Return leftist element of tree (is used on subtree)
leftistElement :: BTree -> (Int, Breakpoint)
leftistElement (Node Nil v _) = v
leftistElement (Node t1 _ _) = leftistElement t1

rightestElement :: BTree -> (Int, Breakpoint)
rightestElement (Node _ v Nil) = v
rightestElement (Node _ _ t2) = rightestElement t2

inOrderSuccessor :: (RealFrac a, Show a, Floating a, Ord a, V.Unbox a)
         => a -> Breakpoint -> a -> V.Vector (Point a) -> BTree -> Breakpoint
inOrderSuccessor x break d ps tree =
  let
    go s Nil = s
    go succ (Node l b r)
      | break == snd b = succ
      | x < updated = go (snd b) l
      | x > updated = go succ r
      | otherwise = succ
      where
        updated = updateBreakpoint (snd b) ps d
  in
    case lookFor x break d ps tree of
      Node _ _ n@(Node {}) -> snd $ leftistElement n
      _ -> go (0, 0) tree

inOrderPredecessor :: (RealFrac a, Show a, Floating a, Ord a, V.Unbox a)
         => a -> Breakpoint -> a -> V.Vector (Point a) -> BTree -> Breakpoint
inOrderPredecessor x break d ps tree =
  let
    go s Nil = s
    go succ (Node l b r)
      | break == snd b = succ
      | x < updated = go succ l
      | x > updated = go (snd b) r
      | otherwise = succ
      where
        updated = updateBreakpoint (snd b) ps d
  in
    case lookFor x break d ps tree of
      Node n@(Node {}) _ _ -> snd $ rightestElement n
      _ -> go (0, 0) tree



joinPairAt :: (RealFrac a, Show a, Floating a, Ord a, V.Unbox a)
       => a -> Index -> Index -> Index -> a -> a -> V.Vector (Point a) -> BTree -> BTree 
joinPairAt x i j k d d' ps tree =
  insert x i k d ps $ delete2 x1 b1 x2 b2 d' ps tree
  where
    x1 = updateBreakpoint b1 ps d'
    x2 = updateBreakpoint b2 ps d'
    b1 = (i, j)
    b2 = (j, k)