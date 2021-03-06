
-- C Curve:
-- ./FractalMaker -o fn.svg -w 800 -n 6 -x "scale 0.5 rotate -90 continue continue rotate 90"
-- Heighway:
-- ./FractalMaker -o fn.svg -w 800 -n 12 -a -x "scale 0.7 rotate -45 reverse rotate 225"
-- Koch: 
-- ./FractalMaker -o fn.svg -w 800 -n 7 -x "scale 0.3334 continue rotate 60 rotate -60 continue"

{-# LANGUAGE NoMonomorphismRestriction #-}
{-# LANGUAGE TypeFamilies              #-}
{-# LANGUAGE NoMonomorphismRestriction #-}
{-# LANGUAGE FlexibleContexts          #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE FlexibleInstances         #-}
 
import Diagrams.Backend.SVG.CmdLine
import Options.Applicative hiding ((<|>))
import Diagrams.Backend.CmdLine
import Diagrams.Prelude
import System.Environment
import Data.Colour
import Data.Char
import Control.Monad
import Data.Either
import Data.Maybe
import AParser
import System.IO
import Diagrams.TwoD.Layout.Grid


-- Command line option setup
data FractOpts = FractOpts
   { 
    optRecurse :: Int,
    allOrOne :: Bool,
    instructions :: String
   }

instance Parseable FractOpts where
    parser = fractOpts

fractOpts :: Options.Applicative.Parser FractOpts 
fractOpts = FractOpts <$> recurse <*> howMany <*> instruct

howMany :: Options.Applicative.Parser Bool
howMany = switch ( long "showAll" <> short 'a' <> help "Show all fractal steps rather than only last iteration. " )

recurse :: Options.Applicative.Parser Int 
recurse = Options.Applicative.option auto ( long "numReplacements" <> short 'n' <> help "Number of replacements. " ) 

fileName :: Options.Applicative.Parser String 
fileName = strOption ( long "filename" <> short 'f' <> help "Filename with instructions. " ) 

instruct :: Options.Applicative.Parser String
instruct = strOption ( long "instructions" <> short 'x' <> help "Instructions for constructing fractal." ) 

-- Some hard-coded fractal examples
cCurve2 curves =  (curves # rotate ((-90) @@ deg) 
                                <> curves 
                                <> curves
                                <> curves # rotate (90 @@ deg)) # scale 0.5


dragon trail = (trail # rotate (-45.0 @@ deg)
               <> trail # rotate (225.0 @@ deg)
               # reverseTrail)
               # scale (1/1.41421356237) 
               
        
koch trail = (trail 
                     <> trail # rotateBy (1/6) 
                     <> trail # rotateBy (-1/6) 
                     <> trail)
                     # scale (1/3)  


-- Looks nasty! For some reason I couldn't make the type-checker happy with 
-- [] -> [] 
-- This function takes the given list of commands and executes them on the trail
genFract expr trail = case expr of 
                        ((Rotate x) : []) -> trail # rotate (x @@ deg) 
                        ((Scale x) : []) -> trail # scale x
                        (Reverse : []) -> trail # reverseTrail
                        (Continue : []) -> trail
                        ((Rotate x) : xs) -> trail # rotate (x @@ deg) <> genFract xs trail 
                        ((Scale x) : xs) -> (genFract xs trail) # scale x
                        (Reverse : xs) -> (genFract xs trail) # reverseTrail
                        (Continue : xs) -> trail <> (genFract xs trail)
          

-- This line was taken from Pontous Granstrom: 
-- https://archives.haskell.org/projects.haskell.org/diagrams/gallery/HeighwayDragon.html
-- His code was used as my starter. 
fractal instructions = map (trailLike . (`at` origin)) (iterate dragon initialTrail)
   where
     initialTrail = hrule 1


data Expr where 
    Rotate  :: Double -> Expr
    Scale   :: Double -> Expr 
    Continue :: Expr 
    Reverse :: Expr 
    Color :: String -> Expr 
    deriving Show 

-- Separates out a string of commands into a list
toEvalList :: String -> [Expr]
toEvalList [] = []
toEvalList s = case runParser parse s of 
                Nothing -> []
                Just (x,s2) -> x : toEvalList s2


-- Parsers for commands, self-explanatory 
-- These should all be condensed b/c of code repetition IMO but I am unsure of how to properly do that.
parseRotate :: AParser.Parser Expr 
parseRotate = string "rotate" *> spaces *> (Rotate <$> parseNum) <* spaces

parseScale :: AParser.Parser Expr
parseScale = string "scale" *> spaces *> (Scale <$> parseNum) <* spaces

parseReverse :: AParser.Parser Expr
parseReverse = string "reverse" *> spaces *> pure Reverse <* spaces 

parseContinue :: AParser.Parser Expr
parseContinue = string "continue" *> spaces *> pure Continue <* spaces 

parseColor :: AParser.Parser Expr
parseColor = string "color" *> spaces *> (Color <$> stringParser) <* spaces 

parse :: AParser.Parser Expr
parse = parseRotate <|> parseScale <|> parseReverse <|> parseContinue

-- This is my main function that sets up the fractal & passes in command args 
-- switches on showing all diagrams vs. last diagram
fract (FractOpts n showAll instructs) = case showAll of 
                                True -> (fractal (toEvalList instructs)
                                        # take n
                                        # sameBoundingRect
                                        # gridSnake
                                        # lineTexture gradient
                                        # lw ultraThin) # pad 1.5
                                False -> head (reverse (fractal (toEvalList instructs)
                                        # take n 
                                        # lineTexture gradient
                                        # lw medium)) # pad 1.5

main = mainWith (fract :: FractOpts -> Diagram B)

-- Styling code from your tutorial
stops = mkStops [(teal, 0, 1), (purple, 1, 1)]
gradient = mkLinearGradient stops ((-1) ^& (-1)) (1 ^& 1) GradPad



-- starter code for integrating files
-- d :: FilePath -> FractOpts -> IO (QDiagram B (V B) (N B) Any)
-- d file (FractOpts n showAll) = do
--     instructs <- handleFile file  
--     case showAll of 
--         True -> (fractal (toEvalList instructs)
--                 # take n
--                 # sameBoundingRect
--                 # gridSnake
--                 # lw ultraThin) # pad 1.5
--         False -> head (reverse (fractal (toEvalList instructs)
--                 # take n 
--                 # lw medium)) # pad 1.5
    

-- handleFile :: FilePath -> IO String 
-- handleFile f = do
--      withFile f ReadMode (\handle -> do 
--          contents <- hGetContents handle    
--          return contents)