module Test.Stream (testStream) where

import Prelude

import Data.Either (Either(Right))
import Data.Maybe (Maybe(Nothing, Just))
import Effect (Effect)
import Effect.Aff (makeAff, nonCanceler)
import SodiumFRP.Stream (
    newStreamSink, 
    listen, 
    send, 
    toStream,
    mapTo,
    orElse
)

import SodiumFRP.Transaction (runTransaction)
import Test.Unit (suite, test)
import Test.Unit.Assert as Assert
import Test.Unit.Main (runTest)
import Effect.Ref as Ref
import Data.List (List(Nil), snoc, length, fromFoldable)

testStream :: Effect Unit
testStream = runTest do
    suite "basic stream tests" do
        test "test single send" do
            let a = newStreamSink Nothing
            result <- makeAff (\cb -> do
                unlisten <- listen (toStream a) \value ->
                    cb $ Right value 
                send 2 a
                unlisten
                pure nonCanceler 
            )
            Assert.equal result 2
        test "test single send with map" do
            let a = newStreamSink Nothing
            let b = ((\x -> x + x) :: Int -> Int) <$> (toStream a)
            result <- makeAff (\cb -> do
                unlisten <- listen b \value ->
                    cb $ Right value 
                send 2 a
                unlisten
                pure nonCanceler 
            )
            Assert.equal result 4

        test "test multi send with map" do
            let a = newStreamSink Nothing
            let b = ((\x -> x + x) :: Int -> Int) <$> (toStream a)
            results <- makeAff (\cb -> do
                refList <- Ref.new (Nil :: List Int)
                unlisten <- listen b \value -> do
                    Ref.modify_ (\xs -> snoc xs value) refList
                    xs <- Ref.read refList
                    if (length xs == 2) then (cb $ Right xs) else (pure unit)
                send 2 a
                send 3 a
                unlisten
                pure nonCanceler 
            )
            Assert.equal (fromFoldable [4, 6]) results

        test "test mapTo" do
            let a = newStreamSink Nothing
            let b = mapTo 4 (toStream a)
            result <- makeAff (\cb -> do
                unlisten <- listen b \value ->
                    cb $ Right value 
                send 2 a
                unlisten
                pure nonCanceler 
            )
            Assert.equal result 4

    suite "merge stream tests" do
        test "test merge left" do
            let a = newStreamSink (Just $ \l -> \r -> l)
            let b = ((\x -> x + x) :: Int -> Int) <$> (toStream a)
            result <- makeAff (\cb -> do
                unlisten <- listen b \value -> 
                    cb $ Right value 
                runTransaction (
                    do 
                        send 2 a
                        send 3 a
                )
                unlisten
                pure nonCanceler 
            )
            Assert.equal (4) result
        test "test merge right" do
            let a = newStreamSink (Just $ \l -> \r -> r)
            let b = ((\x -> x + x) :: Int -> Int) <$> (toStream a)
            result <- makeAff (\cb -> do
                unlisten <- listen b \value ->
                    cb $ Right value 
                runTransaction (
                    do 
                        send 2 a
                        send 3 a
                )
                unlisten
                pure nonCanceler 
            )
            Assert.equal (6) result
        test "test orElse" do
            let a = newStreamSink Nothing 
            let b = newStreamSink Nothing
            let c = orElse (toStream a) (toStream b)
            result <- makeAff (\cb -> do
                unlisten <- listen c \value ->
                    cb $ Right value 
                runTransaction (
                    do 
                        send 2 a
                        send 3 b
                )
                unlisten
                pure nonCanceler 
            )
            Assert.equal 3 result