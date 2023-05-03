function readWasmUint32(memory, ptr) {
    return new Uint32Array(
        memory.buffer,
        ptr,
        1,
    )[0];
}

// "2d", "webgl", or "webgl2":
// * "2d" is Canvas2D, a very simple API for drawing graphics on the web.
// * "webgl" is OpenGL for the web: WebGL. It is more low-level.
//   This will not work if the grid's width or height is not a power of two.
// * "webgl2" is in our case practically the same as "webgl" but
//   allows for non-power of two texture (grid) width and height.
// TODO: support "bitmaprenderer"?
// TODO: support WebGPU when it's ready
const canvasContextType = "webgl2";

WebAssembly.instantiateStreaming(
    fetch("web-example.wasm"),
    {
        env: {
            // hand this over to zig
            "Math.random": () => Math.random(),
        }
    },
).then(wasm => {
    const exports = wasm.instance.exports;

    const memory = exports.memory;

    const init = exports.init;
    const tick = exports.tick;
    const onmousemove = exports.onmousemove;
    const onmousedown = exports.onmousedown;
    const onmouseup = exports.onmouseup;

    const gridPointer = readWasmUint32(memory, exports.grid_ptr.value);
    const width = readWasmUint32(memory, exports.width.value);
    const height = readWasmUint32(memory, exports.height.value);

    const canvas = document.getElementById("canvas");
    canvas.width = width;
    canvas.height = height;
    const context = getContext(canvas);

    canvas.onmousemove = (event) => onmousemove(event.layerX, event.layerY);
    canvas.onmousedown = (event) => onmousedown(event.layerX, event.layerY);
    canvas.onmouseup = (event) => onmouseup(event.layerX, event.layerY);

    init();

    function loop(now) {
        tick(now);

        const pixels = new Uint8ClampedArray(memory.buffer, gridPointer, 4 /* RGBA */ * width * height);
        draw(context, pixels, width, height);

        // make sure we don't do anything async in this callback
        animationFrameRequestHandle = window.requestAnimationFrame(loop);
    };
    animationFrameRequestHandle = window.requestAnimationFrame(loop);
});

function draw(context, pixels, width, height) {
    if (canvasContextType === "2d") {
        const imageData = new ImageData(pixels, width, height);
        context.putImageData(imageData, 0, 0);
    } else if (canvasContextType === "webgl" || canvasContextType === "webgl2") {
        const gl = context;

        gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, width, height, 0, gl.RGBA, gl.UNSIGNED_BYTE, pixels)
        gl.drawArrays(
            gl.TRIANGLES,
            0,
            6, // the amount of coordinates we specified for our rectangle below
        );
    }
}

function getContext(canvas) {
    if (canvasContextType === "2d") {
        return canvas.getContext("2d");
    } else if (canvasContextType === "webgl" || canvasContextType === "webgl2") {
        // this is how we create the geometry we see on the screen
        const vertexShaderSource =
            `
            attribute vec4 position;

            varying vec2 v_texcoord;

            void main() {
              gl_Position = position;
              v_texcoord = vec2(position.x, -position.y) * 0.5 + 0.5;
            }
            `;
        // this is how we determine the color we see on the screen
        const fragmentShaderSource =
            `
            precision mediump float;

            varying vec2 v_texcoord;

            uniform sampler2D texture;

            void main() {
              vec4 color = texture2D(texture, v_texcoord);
              gl_FragColor = color;
            }
            `;

        const gl = canvas.getContext(canvasContextType);

        const program = gl.createProgram();

        const vertexShader = gl.createShader(gl.VERTEX_SHADER);
        gl.shaderSource(vertexShader, vertexShaderSource)
        gl.compileShader(vertexShader)
        gl.attachShader(program, vertexShader);

        const fragmentShader = gl.createShader(gl.FRAGMENT_SHADER);
        gl.shaderSource(fragmentShader, fragmentShaderSource)
        gl.compileShader(fragmentShader)
        gl.attachShader(program, fragmentShader);

        gl.linkProgram(program);
        gl.useProgram(program);

        const buffer = gl.createBuffer();
        gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
        gl.bufferData(
            gl.ARRAY_BUFFER,
            new Float32Array([
                // vectors for a rectangle
                -1, -1,
                 1, -1,
                -1,  1,
                -1,  1,
                 1, -1,
                 1,  1,
            ]),
            gl.STATIC_DRAW
        );

        const positionLocation = gl.getAttribLocation(program, "position");
        gl.enableVertexAttribArray(positionLocation);
        gl.vertexAttribPointer(positionLocation, 2, gl.FLOAT, false, 0, 0);

        const texture = gl.createTexture();
        gl.bindTexture(gl.TEXTURE_2D, texture);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);

        return gl;
    } else {
        console.error(`invalid canvas context type ${canvasContextType}`);
    }
}
