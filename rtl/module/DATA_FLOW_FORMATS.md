# CNN fixed-point data flow

This note describes the fixed-point formats expected by `layer1`, `neuron`,
`activation_function`, and `output_layer`. The formats are conventions applied
to the bits; the Verilog ports do not carry a fixed-point type or automatically
convert between real numbers and fixed-point integers.

## Data flow

```text
input producer
  20 signed Q8.8 samples
       |
       v
layer1 / neuron
  Q8.8 sample * Q8.8 weight -> Q16.16 product
  sum of products + Q16.16 bias -> signed Q16.16 sum
       |
       v
activation_function
  signed Q16.16 input -> unsigned Q0.16 sigmoid output
       |
       v
layer1.m_data
  10 packed unsigned Q0.16 activations (160 bits total)
       |
       v
output_layer
  Q0.16 activation * signed Q8.8 weight
  -> Q8.24 product, arithmetic shift right by 8 -> Q16.16
  sum of products + Q16.16 bias -> Q16.16 sum
       |
       v
activation_function
  signed Q16.16 input -> unsigned Q0.16 output
```

## Formats at each boundary

| Signal or value | Width and signedness | Expected format | Meaning |
|---|---:|---|---|
| `layer1.s_data` / `neuron.data_in` | 16-bit signed | Q8.8 | Input sample; the producer must encode it before presenting it. |
| `neuron.weight_in` | 16-bit signed | Q8.8 | Weight loaded by `layer1` from its weight memory file. |
| `neuron.product` | 32-bit signed | Q16.16 | Product of two Q8.8 values; the neuron sign-extends it but does not rescale it. |
| `neuron.bias_in` | 40-bit signed | Q16.16 | Bias added to the accumulated products. |
| `neuron.sum_out` / `layer1.neuron_sum` | 40-bit signed | Q16.16 | Weighted sum supplied to the activation function. |
| `activation_function.value_in` | 40-bit signed | Q16.16 | Already-scaled input; activation does not convert from a real number. |
| `activation_function.value_out` | 16-bit unsigned | Q0.16 | Sigmoid result in the range 0 through 65535, representing 0 through just under 1. |
| `layer1.m_data` | 160-bit unsigned packed bus | 10 x Q0.16 | Activation `i` occupies bits `i*16` through `i*16+15`. |
| `output_layer.weights` | 16-bit signed | Q8.8 | Weights for the second layer. |
| `output_layer.biases` / `weighted_sum` | 40-bit signed | Q16.16 | Bias and weighted sum for the second layer. |
| `output_layer.m_data` | 16-bit unsigned | Q0.16 | Final sigmoid output. |

Q-format labels here specify the number of fractional bits. The important scale
rule is that multiplying values with `F1` and `F2` fractional bits produces a
product with `F1 + F2` fractional bits. For example, Q8.8 multiplied by Q8.8
produces Q16.16. Adding values is only scale-consistent when they have the same
number of fractional bits.

## Example: one neuron product

To represent 1.5 as Q8.8, the input producer supplies:

```text
1.5 * 2^8 = 384
```

To represent 0.5 as Q8.8, the weight memory contains the signed integer 128.
The neuron multiplies these integers:

```text
384 * 128 = 49,152
```

That product is interpreted as Q16.16, so its real value is:

```text
49,152 / 2^16 = 0.75
```

The neuron adds the Q16.16 bias to this product (and the other products in the
dot product). No `* 256`, division, rounding, or other fixed-point conversion
is performed by `neuron.v`.

## Example: activation input

The real value 1.5 as Q16.16 is the raw integer `1.5 * 2^16 = 98,304`. That
conversion must have happened before the value reaches
`activation_function.value_in`. The activation module uses the signed raw
Q16.16 value directly for its lookup and interpolation. Its range clamps at
-8.0 and +8.0, encoded as -524,288 and +524,288.

The result is an unsigned Q0.16 number. For example, 32,768 represents 0.5.
The maximum output, 65,535, represents `65,535 / 65,536`, just below 1.0.

## Integration checks

- The producer feeding `layer1.s_data` must emit signed Q8.8 values. The port
  width and signed declaration alone do not perform this encoding.
- The `layer1` weight files must contain signed Q8.8 integers, and its bias
  file must contain signed Q16.16 integers.
- Values added in each accumulator must use the same Q16.16 scale.
- The 160-bit output of `layer1` is already the 10-value input format expected
  by `output_layer`; each activation is treated there as unsigned Q0.16.
- The second layer's weight file is signed Q8.8 and its bias file is signed
  Q16.16.
- `$readmemh` loads bit patterns only; it does not convert decimal values or
  infer a fixed-point format. Ensure model export or memory-file generation
  uses the scales listed above.
