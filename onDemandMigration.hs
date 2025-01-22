{-# LANGUAGE OverloadedStrings #-}
module Main where

import Data.Map.Strict (Map)
import qualified Data.Map.Strict as M
import Data.Text (Text)
import qualified Data.Text as T
import System.IO

-- | A 'SchemaObject' might represent a table, document collection, or graph node type.
data SchemaObject = SchemaObject
  { objName      :: Text
  , objFields    :: [Text]  -- For simplicity: list of field/attribute names
  } deriving (Show, Eq)

-- | A 'SchemaMorphism' from one schema to another, describing how fields map.
data SchemaMorphism = SchemaMorphism
  { morphSource   :: Text
  , morphTarget   :: Text
  , fieldMappings :: Map Text Text
  } deriving (Show, Eq)

-- | A 'SchemaCategory' holds multiple objects and morphisms (functors in a broader sense).
data SchemaCategory = SchemaCategory
  { catObjects   :: Map Text SchemaObject
  , catMorphisms :: [SchemaMorphism]
  } deriving (Show)

-- | A sample data record: for demonstration, let's store them as Map Text Text
type RecordData = Map Text Text

-- | A 'TransformationEngine' might handle on-demand transformations between schema categories.
data TransformationEngine = TransformationEngine
  { category :: SchemaCategory
  } deriving (Show)

-- | Create a new schema category with no objects or morphisms.
emptyCategory :: SchemaCategory
emptyCategory = SchemaCategory M.empty []

-- | Add a new object to the category
addObject :: SchemaObject -> SchemaCategory -> SchemaCategory
addObject obj (SchemaCategory objs morphs) =
  SchemaCategory (M.insert (objName obj) obj objs) morphs

-- | Add a morphism to the category
addMorphism :: SchemaMorphism -> SchemaCategory -> SchemaCategory
addMorphism morph (SchemaCategory objs morphs) =
  SchemaCategory objs (morph : morphs)

-- | Look up a direct schema morphism from 'source' to 'target'
findDirectMorphism :: Text -> Text -> [SchemaMorphism] -> Maybe SchemaMorphism
findDirectMorphism s t = foldl (\acc m -> if morphSource m == s && morphTarget m == t
                                          then Just m else acc) Nothing

-- | Perform an on-demand transformation of a single data record
onDemandTransform :: TransformationEngine
                  -> Text          -- ^ Source schema name
                  -> Text          -- ^ Target schema name
                  -> RecordData    -- ^ Data in source schema format
                  -> Either Text RecordData
onDemandTransform (TransformationEngine cat) s t rec =
  case findDirectMorphism s t (catMorphisms cat) of
    Nothing -> Left $ "No direct morphism found from " <> s <> " to " <> t
    Just morph -> 
      let mappings = fieldMappings morph
          newMap   = foldl (\acc (srcF, val) ->
                              case M.lookup srcF mappings of
                                Nothing     -> acc -- field is unmapped
                                Just tgtF   -> M.insert tgtF val acc
                           ) M.empty (M.toList rec)
      in Right newMap

-- | Main: Minimal demonstration
main :: IO ()
main = do
  let userV1 = SchemaObject "UserV1" ["id", "name"]
      userV2 = SchemaObject "UserV2" ["uuid", "fullName"]

      morphMap = M.fromList [("id", "uuid"), ("name", "fullName")]
      userMorphism = SchemaMorphism "UserV1" "UserV2" morphMap

      initCat = emptyCategory
                `addObject` userV1
                `addObject` userV2
                `addMorphism` userMorphism

      engine = TransformationEngine initCat

      -- Example record in the source (UserV1) schema
      record :: RecordData
      record = M.fromList [("id", "abc-123"), ("name", "Alice")]

  case onDemandTransform engine "UserV1" "UserV2" record of
    Left err    -> putStrLn $ "Error: " ++ T.unpack err
    Right newRec -> putStrLn $ "Transformed record: " ++ show newRec
