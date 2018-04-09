var path = require('path'),
    webpack = require('webpack'),
    merge = require('webpack-merge'),
    HtmlWebpackPlugin = require('html-webpack-plugin'),
    CopyWebpackPlugin = require('copy-webpack-plugin');

var PATH_BASE = path.resolve(__dirname, '.') + '/',
    PATH_BUILD = PATH_BASE + 'docker/build/',
    PATH_SRC = PATH_BASE + 'src/';

var PRODUCTION = 'production',
    DEVELOPMENT = 'development',
    TARGET_ENV = process.env.npm_lifecycle_event === 'build' ? PRODUCTION : DEVELOPMENT,
    isProduction = TARGET_ENV === PRODUCTION,
    isDevelopment = TARGET_ENV === DEVELOPMENT;

var commonConfig = {
    entry: PATH_SRC + 'index.js',
    output: {
        path: PATH_BUILD,
        publicPath: '/',
        filename: isProduction ? '[name]-[hash].js' : '[name].js'
    },
    resolve: {
        extensions: ['.js', '.elm']
    },
    module: {
        noParse: /\.elm$/
    },
    plugins: [
        new HtmlWebpackPlugin({
            template: PATH_SRC + 'index.html',
            inject: 'body',
            filename: 'index.html'
        })
    ]
};

if (TARGET_ENV === 'development') {
    console.info('Serving locally...');

    module.exports = merge(commonConfig, {
        module: {
            rules: [
                {
                    test: /\.elm$/,
                    exclude: [/elm-stuff/, /node_modules/],
                    use: [
                        'elm-hot-loader',
                        {
                            loader: 'elm-webpack-loader',
                            options: {
                                warn: true,
                                debug: false
                            }
                        }
                    ]
                }
            ]
        },
        plugins: [
            new webpack.HotModuleReplacementPlugin()
        ],
        devServer: {
            hot: true,
            inline: true,
            contentBase: PATH_SRC,
            historyApiFallback: true,
            https: true
        }
    });
}

if (TARGET_ENV === 'production') {
    console.info('Building for production...');

    module.exports = merge(commonConfig, {
        module: {
            rules: [
                {
                    test: /\.elm$/,
                    exclude: [/elm-stuff/, /node_modules/],
                    use: 'elm-webpack-loader'
                }
            ]
        },
        plugins: [
            new CopyWebpackPlugin([
                {
                    from: 'src/favicon.ico'
                }
            ]),
            new webpack.optimize.OccurrenceOrderPlugin()
        ],
        optimization: {
            minimize: true
        }
    });
}