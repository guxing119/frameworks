require 'torch'
require 'nn'
require 'optim'
mnist = require 'mnist'

trainset = mnist.traindataset()
testset = mnist.testdataset()

model = nn.Sequential()

model:add(nn.Reshape(28*28))
model:add(nn.Linear(28*28, 500))
model:add(nn.Sigmoid())
model:add(nn.Linear(500, 250))
model:add(nn.Sigmoid())
model:add(nn.Linear(250, 10))

sgd_params = {
   learningRate = 0.1,
   learningRateDecay = 0.0,
   weightDecay = 0.0,
   momentum = 0.9
}

model:add(nn.LogSoftMax())
criterion = nn.ClassNLLCriterion()

x, dl_dx = model:getParameters()

print('<mnist> using model:')
print(model)

step = function(batch_size)
    local current_loss = 0
    local count = 0
    local shuffle = torch.randperm(trainset.size)
    batch_size = batch_size or 100

    for t = 1,trainset.size,batch_size do
        -- setup inputs and targets for this mini-batch
        local size = math.min(t + batch_size - 1, trainset.size) - t
        local inputs = torch.Tensor(size, 28, 28)
        local targets = torch.Tensor(size)
        for i = 1,size do
            local input = trainset.data[shuffle[i+t]]
            local target = trainset.label[shuffle[i+t]]
            -- if target == 0 then target = 10 end
            inputs[i] = input
            targets[i] = target
        end
        targets:add(1)

        local feval = function(x_new)
            -- reset data
            if x ~= x_new then x:copy(x_new) end
            dl_dx:zero()

            -- perform mini-batch gradient descent
            local loss = criterion:forward(model:forward(inputs), targets)
            model:backward(inputs, criterion:backward(model.output, targets))

            return loss, dl_dx
        end

        _, fs = optim.sgd(feval, x, sgd_params)
        -- fs is a table containing value of the loss function
        -- (just 1 value for the SGD optimization)
        count = count + 1
        current_loss = current_loss + fs[1]
    end

    -- normalize loss
    return current_loss / count
end

eval = function(dataset, batch_size)
    local count = 0
    batch_size = batch_size or 100

    for i = 1,dataset.size,batch_size do
        local size = math.min(i + batch_size - 1, dataset.size) - i
        local inputs = dataset.data[{{i,i+size-1}}]
        local targets = dataset.label[{{i,i+size-1}}]:long()
        local outputs = model:forward(inputs)
        local _, indices = torch.max(outputs, 2)
        indices:add(-1)
        local guessed_right = indices:eq(targets):sum()
        count = count + guessed_right
    end

    return count / dataset.size
end

max_iters = 50

trainset.data = trainset.data:double()
testset.data = testset.data:double()

print("Start training")

do
    for i = 1,max_iters do
        local loss = step()
        local accuracy = eval(trainset)
        print(string.format('Epoch: %d loss: %4f train acc: %5f', i, loss, accuracy))
    end
end

local accuracy = eval(testset)
print(string.format('Test acc: %5f', accuracy))
