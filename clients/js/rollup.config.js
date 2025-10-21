import resolve from '@rollup/plugin-node-resolve';
import typescript from '@rollup/plugin-typescript';

export default {
  input: 'src/polyglot.ts',
  output: [
    {
      file: 'dist/polyglot.js',
      format: 'cjs',
      sourcemap: true
    },
    {
      file: 'dist/polyglot.mjs',
      format: 'esm',
      sourcemap: true
    }
  ],
  plugins: [
    resolve(),
    typescript({
      tsconfig: './tsconfig.json',
      exclude: ['**/*.test.ts']
    })
  ],
  external: ['ws']
};
