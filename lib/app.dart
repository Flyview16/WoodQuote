import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wood_quote/bloc/cubit/estimates_cubit.dart';
import 'package:wood_quote/screens/home_wrapper.dart';
import 'package:wood_quote/utils/theme.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => EstimatesCubit()..loadEstimates(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: "WoodQuote",
        theme: theme,
        home: HomeWrapper(),
      ),
    );
  }
}
