const path = require('path');
const MiniCssExtractPlugin = require("mini-css-extract-plugin");
const StringReplacePlugin = require("string-replace-webpack-plugin");

module.exports = {
    mode: 'production', // or 'development' for production builds
    entry: __dirname + '/src/index.js',
    output: {
        path: __dirname + '/docs',
        filename: 'index.js'
    },

    module: {
        rules: [
            {
                test: /\.(js|js6)$/,
                use: [
                    { loader: 'babel-loader', options: { presets: ['@babel/env'] } }
                ],
                exclude: /node_modules/
            },
            {
                test: /\.css$/,
                use: [
                    { loader: MiniCssExtractPlugin.loader, options: { publicPath: './docs' } },
                    { loader: 'css-loader', options: { sourceMap: true } }
                ]
            },
            {
                test: /\.scss$/,
                use: [
                    { loader: MiniCssExtractPlugin.loader, options: { publicPath: './docs' } },
                    { loader: 'css-loader', options: { sourceMap: true } },
                    { loader: 'sass-loader', options: { sourceMap: true } },
                ]
            },
            {
                test: /\.html$/,
                use: [
                    { loader: 'file-loader', options: { name: '[name].html' } },
                    {
                        loader: StringReplacePlugin.replace({
                            replacements: [
                                {
                                    pattern: /\[hash\]/g,
                                    replacement: function () {
                                        const randomhash = new Date().toString().replace(/\W/g, '_');
                                        return randomhash;
                                    }
                                },
                            ]
                        })
                    }
                ]
            },
            {
                test: /\.(svg|gif|jpg|jpeg|png)$/,
                loader: 'url-loader',
                options: { 
                    limit: 1000, // Convert images < 1kb to base64 strings
                    name: 'images/[hash]-[name].[ext]'
                }
            },
            {
                test: /\.(woff|woff2|ttf|eot)$/,
                loader: 'ignore-loader'
            }
        ]
    },

    devtool: "nosources-source-map",

    plugins: [
        new MiniCssExtractPlugin({
            filename: 'index.css',
        }),
        new StringReplacePlugin(),
    ],

    devServer: {
        static: {
            directory: path.join(__dirname, 'docs'), // Updated for webpack 5+
        },
        port: 8182,
        compress: true,
        open: true, // Automatically open the browser
        watchFiles: ['src/**/*', 'docs/**/*'], // Watch files inside src and docs for changes
    }
};

