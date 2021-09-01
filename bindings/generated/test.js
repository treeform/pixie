var pixie = require('./pixie');

var image100 = pixie.image(100, 100)
console.log(image100)
image100.fill(pixie.color(1, 1, 0, 10))
image100.writeFile("just_a_test.png")
//image100.unref()

console.log("done");
