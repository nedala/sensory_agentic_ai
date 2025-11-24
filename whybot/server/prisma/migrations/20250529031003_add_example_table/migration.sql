-- CreateTable
CREATE TABLE "Example" (
    "id" SERIAL NOT NULL,
    "persona" TEXT NOT NULL,
    "model" TEXT NOT NULL,
    "tree" JSONB NOT NULL,
    "rootQuestion" TEXT NOT NULL,
    "normalizedRoot" TEXT NOT NULL,

    CONSTRAINT "Example_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "Example_normalizedRoot_key" ON "Example"("normalizedRoot");
