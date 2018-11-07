#Util lib.
import Ember/lib/Util

#Numerical libs.
import BN
import Ember/lib/Base

#Hash lib.
import Ember/lib/Hash

#BLS lib.
import Ember/lib/BLS

#Merit objects.
import Ember/Merit/objects/DifficultyObj
import Ember/Merit/objects/MinersObj

#Merit libs.
import Ember/Merit/Verifications
import Ember/Merit/MinerWallet
import Ember/Merit/Block

#Block Serialization lib.
import Ember/Serialize/SerializeBlock

#Ember RPC lib.
import EmberRPC

#OS standard lib.
import os

#Async standard lib.
import asyncdispatch

#JSON standard lib.
import json

#Main function is so these variables can be GC'd.
proc main() {.async.} =
    var
        #Connect to the EMB Node.
        rpc: EmberRPC = await newEmberRPC()
        #Create a Wallet for signing Verifications.
        miner: MinerWallet

    #If there are params...
    if paramCount() > 0:
        #If a key was passed...
        miner = newMinerWallet(newBLSPrivateKeyFromBytes(paramStr(1)))
    else:
        #Else, create a new wallet.
        miner = newMinerWallet()
        echo "No wallet was passed in. A new one has been created with a Private Key of " & $miner.privateKey & "."

    var
        #Difficulty.
        difficulty: BN
        #Gensis string.
        genesis: string = "mainnet"
        #Block.
        newBlock: Block
        #Nonce.
        nonce: uint = 1
        #Last Block hash.
        last: ArgonHash = (
            await rpc.merit.getBlock(
                (await rpc.merit.getHeight()) - 1
            )
        )["argon"].getStr().toArgonHash()
        #Verifications object.
        verifs: Verifications = newVerificationsObj()
        #Miners object.
        miners: Miners = @[(
            newMinerObj(
                miner.publicKey,
                100
            )
        )]
    #Calculate the Verifications' signature.
    verifs.calculateSig()

    #Mine the chain.
    while true:
        #Get the difficulty.
        difficulty = newBN(await rpc.merit.getDifficulty())

        #Create a block.
        newBlock = newBlock(
            nonce,
            last,
            verifs,
            miners
        )

        #Mine it.
        while true:
            try:
                #Make sure the Block beats the difficulty.
                if newBlock.argon.toBN() < difficulty:
                    raise newException(Exception, "Block didn't beat the Difficulty.")

                #Publish the block.
                try:
                    await rpc.merit.publishBlock(newBlock.serialize())
                except:
                    echo "The miner submitted a Block the Node considered invalid."
                    quit(-1)

                #If we succeded, break.
                break
            except:
                #Increase the proof.
                inc(newBlock)

        #Print that we mined a block.
        echo "Mined a block: " & $nonce

        #Increase the nonce.
        inc(nonce)
        #Update last.
        last = newBlock.argon

asyncCheck main()
runForever()