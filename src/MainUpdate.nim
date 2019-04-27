include MainLocks

#Get the most recent Verifications.
proc getVerifs() {.async.} =
    records = @[]
    aggregates = @[]

    var jsonVerifs: JSONNode = await rpc.verifications.getUnarchivedVerifications()
    for record in jsonVerifs:
        records.add(
            newVerifierRecord(
                newBLSPublicKey(record["verifier"].getStr()),
                record["nonce"].getInt(),
                record["merkle"].getStr().toHash(384)
            )
        )
        aggregates.add(newBLSSignature(record["signature"].getStr()))

#Reset all data.
#This is used when someone else mines a Block or we publish an invalid one.
proc reset() {.async.} =
    #Acquire the RPC.
    await acquireRPC()

    #Nonce.
    nonce = await rpc.merit.getHeight()

    #Difficulty.
    difficulty = (await rpc.merit.getDifficulty()).toBNFromHex()

    #Last.
    last = (
        await rpc.merit.getBlock(
            nonce - 1
        )
    )["header"]["hash"].getStr().toArgonHash()

    #Verifications.
    await getVerifs()

    #Release the RPC.
    releaseRPC()

    #Create a block.
    mining = newBlockObj(nonce, last, aggregates.aggregate(), records, miners)

#Check for Verifications.
proc checkup() {.async.} =
    while true:
        #Run every thirty seconds.
        await sleepAsync(30000)

        var
            #New Nonce.
            newNonce: int
            #New Last Hash.
            newLast: ArgonHash

        #Get the current Blockchain Height and Last Hash.
        await acquireRPC()
        newNonce = await rpc.merit.getHeight()
        newLast = (
            await rpc.merit.getBlock(
                newNonce - 1
            )
        )["header"]["hash"].getStr().toArgonHash()
        releaseRPC()

        #If someone else mined a block...
        if newNonce != nonce:
            await reset()
            return

        #If the chain forked...
        if newLast != last:
            await reset()
            return

        #Get the Verifications.
        await acquireRPC()
        await getVerifs()
        releaseRPC()

        #Construct a new block.
        mining = newBlockObj(nonce, last, aggregates.aggregate(), records, miners)
