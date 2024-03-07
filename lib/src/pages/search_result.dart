import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:shopos/src/blocs/product/product_cubit.dart';
import 'package:shopos/src/blocs/report/report_cubit.dart';
import 'package:shopos/src/config/colors.dart';
import 'package:shopos/src/models/input/order.dart';
import 'package:shopos/src/models/membershipPlan_model.dart';
import 'package:shopos/src/pages/checkout.dart';
import 'package:shopos/src/pages/create_product.dart';
import 'package:shopos/src/services/global.dart';
import 'package:shopos/src/services/locator.dart';
import 'package:shopos/src/services/search_service.dart';
import 'package:shopos/src/services/set_or_change_pin.dart';
import 'package:shopos/src/widgets/custom_button.dart';
import 'package:shopos/src/widgets/custom_text_field.dart';
import 'package:shopos/src/widgets/custom_text_field2.dart';
import 'package:shopos/src/widgets/product_card_horizontal.dart';

import '../models/product.dart';
import '../widgets/pin_validation.dart';

class PlanListPageArgs {
  final bool isSelecting;
  final OrderType orderType;

  List<OrderItemInput> membershipPlanList = [];
  PlanListPageArgs({required this.isSelecting, required this.orderType, required this.membershipPlanList});
}

class SearchProductListScreen extends StatefulWidget {
  static const routeName = '/search-product-list-screen';

  SearchProductListScreen({required this.args});
  final PlanListPageArgs? args;

  @override
  State<SearchProductListScreen> createState() =>
      _SearchProductListScreenState();
}

class _SearchProductListScreenState extends State<SearchProductListScreen> {
  final scrollController = ScrollController();
  final SearchProductServices searchProductServices = SearchProductServices();
  List<MembershipPlanModel> planList = [];
  bool isLoadingMore = false;
  late final MembershipCubit _productCubit;
  late List<MembershipPlanModel> _memberships;
  bool itemCheckedFlag = false;
  TextEditingController searchController = TextEditingController();

  int page = 0;
  int _currentPage = 1;
  int _limit = 20;
  bool isAvailable = true;
  PinService _pinService = PinService();
  late final ReportCubit _reportCubit;
  final TextEditingController pinController = TextEditingController();

  int expiryDaysTOSearch = 7;
  String searchMode = "normalSearch";

  @override
  void initState() {
    super.initState();
    _memberships = [];
    _productCubit = MembershipCubit()..getAllPlans();
    scrollController.addListener(_scrollListener);
    _reportCubit = ReportCubit();
    fetchSearchedProducts();
  }

  //goToProductDetails(BuildContext context, int idx) {
  // Navigator.of(context).pushNamed(SearchProductDetailsScreen.routeName,
  //    arguments: prodList[idx]);
  //}
  @override
  void dispose() {
    _reportCubit.close();
    super.dispose();
  }

  Future<void> fetchSearchedProducts() async {
    List newPlans = [];
    if (searchMode == "normalSearch") {
      print("in normal search");
      newPlans = await searchProductServices.allPlans();
    } else if (searchMode == "expiry") {//todo: remove filters
      var list = await searchProductServices.searchByExpiry(expiryDaysTOSearch);
      if (list.isEmpty) {
        locator<GlobalServices>().errorSnackBar(" No items expiring within the specified days.");
      } else {
        newPlans = list;
      }
    }

    // this  is used for removing duplicating items when paging
    for (var plan in newPlans) {
      bool checkFlag = false;
      planList.forEach((element) {
        if (element.id == plan.id) {
          checkFlag = true;
        }
      });
      if (!checkFlag) {
        planList.add(plan);
      }
    }

    // To show the same quantity selected in search page list also
    for (int i = 0; i < widget.args!.membershipPlanList.length; i++) {
      for (int j = 0; j < planList.length; j++) {
        if (widget.args!.membershipPlanList[i].membership!.id == planList[j].id) {

        }
      }
    }
    print("searched products: $planList");
    setState(() {});
  }

  void _scrollListener() async {
    if (isLoadingMore) return;
    if (scrollController.position.pixels ==
        scrollController.position.maxScrollExtent) {
      _currentPage++;
      setState(() {
        isLoadingMore = true;
      });
      await fetchSearchedProducts();
      setState(() {
        isLoadingMore = false;
      });
    }
  }


  void _selectProduct(MembershipPlanModel membership) {
    final canSelect = widget.args?.isSelecting ?? false;
    if (!canSelect) {
      return;
    }
    _memberships.clear();
    _memberships.add(membership);
    setState(() {});
  }
  void removePlan(MembershipPlanModel membership) {
    for(int i = 0;i<_memberships.length;i++){
      if(_memberships[i].id == membership.id){
        _memberships.removeAt(i);
        break;
      }
    }
  }

  bool isMembershipSelected(MembershipPlanModel membership) {
    for(int i = 0;i<_memberships.length;i++){
      if(_memberships[i].id == membership.id){
        return true;
      }
    }
    return false;
  }

  FocusNode node = FocusNode();

  GlobalKey widgetKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    // final width = MediaQuery.of(context).size.width;

    return Scaffold(
        appBar: AppBar(
          elevation: 0,
          title: Text(
            "Plan List",
            style: TextStyle(
                color: Colors.black,
                fontSize: height / 45,
                fontFamily: 'GilroyBold'),
          ),
          centerTitle: true,
          actions: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: GestureDetector(
                  onTap: () {
                    _showFilterDialog();
                  },
                  child: Icon(Icons.filter_alt)),
            )
          ],
        ),
        floatingActionButton: Container(
          margin: const EdgeInsets.only(
            right: 10,
            left: 30,
            bottom: 20,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.args!.isSelecting)
                CustomButton(
                    title: "Continue",
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    onTap: () {
                      if (_memberships.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: Colors.red,
                            content: Text(
                              "Please select products before continuing",
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        );
                        return;
                      }
                      final _orderItems = _memberships.map((e) => OrderItemInput(membership: e,))
                          .toList();
                      Order _Order = Order(
                          kotId: "",
                          orderItems: _orderItems
                      );
                      Navigator.pushNamed(context, CheckoutPage.routeName, arguments: CheckoutPageArgs(invoiceType: OrderType.sale, order: _Order));
                      // Navigator.pop(
                      //   context,
                      //   _memberships,
                      // );
                    }),
              if (widget.args?.isSelecting ?? false) const SizedBox(width: 20),
              FloatingActionButton(
                onPressed: () async {
                  _productCubit.getAllPlans();

                  await Navigator.pushNamed(
                      context,
                      '/create-plan',
                      arguments: CreatePlanArgs()
                  );
                  _productCubit.getAllPlans();
                },
                backgroundColor: Colors.green,
                child: const Icon(
                  Icons.add,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ],
          ),
        ),
        body: Stack(children: [
          Column(
            children: [
              SizedBox(
                height: 60,
              ),
              planList.length == 0
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 15),
                        child: Text('No plans found!'),
                      ),
                    )
                  : Expanded(
                      child: GridView.builder(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3, mainAxisExtent: 250),
                          padding: EdgeInsets.all(8),
                          itemCount: isLoadingMore
                              ? planList.length + 1
                              : planList.length,
                          controller: scrollController,
                          itemBuilder: (context, index) {
                            if (index < planList.length) {
                              return Container(
                                height: 250,
                                child: Column(
                                  children: [
                                    Stack(
                                      children: [
                                        ProductCardHorizontal(
                                          type: widget.args!.orderType,
                                          isSelecting: widget.args!.isSelecting,
                                          onTap: (q) {
                                            //here q represents the quantity
                                            //if q is 1 that means we should remove the item from main list(productList)
                                            // if q is we should add item to productList

                                            //this logic is done becasue when we press the card only the (+-) button should show and should add item
                                            //then when we again press the card the opposite should happen
                                            print("value of q $q");//q represents item quantity
                                            if (q == 0) {
                                              print("if part");
                                              _selectProduct(planList[index]);
                                              itemCheckedFlag = true;
                                            } else if (q <= 1) {
                                              print("else part");
                                              if(_memberships.isEmpty){
                                                removePlan(planList[index]);
                                              }else{
                                                _selectProduct(planList[index]);
                                              }
                                              itemCheckedFlag = false;
                                            }

                                            setState(() {});
                                          },
                                          membership: planList[index],
                                          onDelete: () async {
                                            var result = true;

                                            if (await _pinService.pinStatus() == true) {
                                              result = await PinValidation.showPinDialog(context) as bool;
                                            }

                                            if (result) {
                                              _productCubit.deletePlan(planList[index]);
                                              // locator<GlobalServices>().infoSnackBar("Delete plan api is not defined");
                                              setState(() {
                                                planList.removeAt(index);
                                              });
                                            }
                                          },
                                          onEdit: () async {
                                            var result = true;

                                            if (await _pinService.pinStatus() == true) {
                                              result = await PinValidation.showPinDialog(context) as bool;
                                            }
                                            if (result) {
                                              await Navigator.pushNamed(
                                                context,
                                                CreatePlan.routeName,
                                                arguments: CreatePlanArgs(id: planList[index].id),
                                              );

                                              pinController.clear();
                                            }
                                          },
                                          onCopy:() async {
                                            var result = true;

                                            if (await _pinService.pinStatus() == true) {
                                              result = await PinValidation.showPinDialog(context) as bool;
                                            }
                                            if (result) {
                                              await Navigator.pushNamed(
                                                context,
                                                CreatePlan.routeName,
                                                arguments: CreatePlanArgs(id: planList[index].id, isCopy: true),
                                              );

                                              // _productCubit.getProducts(_currentPage, _limit);
                                              pinController.clear();
                                            }
                                          },
                                        ),
                                        if (isMembershipSelected(planList[index]))
                                          const Align(
                                            alignment: Alignment.topRight,
                                            child: Padding(
                                              padding: EdgeInsets.all(8.0),
                                              child: CircleAvatar(
                                                radius: 15,
                                                backgroundColor: Colors.green,
                                                child: Icon(
                                                  Icons.check,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            } else {
                              return Center(child: Text("loading"));
                            }
                          }),
                    ),
            ],
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
//               child: CustomTextField(
              child: CustomTextField(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search',
                onChanged: (String e) async {
                  if (e.isNotEmpty) {
                    // planList.clear();
                    setState(() {});
                    //todo: implement search function
                    // planList = await searchProductServices.searchproduct(e);

                    // for (int i = 0; i < widget.args!.membershipPlanList.length; i++) {
                    //   for (int j = 0; j < planList.length; j++) {
                    //     if (widget.args!.membershipPlanList[i].product!.id == planList[j].id) {
                    //       // planList[j].quantity = widget.args!.productlist[i].product!.quantity;
                    //       planList[j].quantityToBeSold = widget.args!.membershipPlanList[i].product?.quantityToBeSold ?? 0;
                    //     }
                    //   }
                    // }
                    // print(_products);

                    print("searchbar running");
                    setState(() {});
                  }
                },
                // onsubmitted: (value) {
                //   Navigator.of(context).push(MaterialPageRoute(
                //     builder: (context) =>
                //         SearchProductListScreen(title: value!),
                //   ));
                // },
              ),
            ),
          ),
        ]));
  }


  Future<bool?> _showFilterDialog() {
    return showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
              content: Container(
                  height: 150,
                  child: Column(
                    children: [
                      ListTile(
                        onTap: () {
                          // _showExpiryFilterDialog();
                        },
                        leading: Text("Expiry"),
                        trailing: Icon(
                          Icons.arrow_forward_ios,
                          size: 15,
                        ),
                      ),
                    ],
                  )),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Filter'),
                  GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                      },
                      child: Icon(Icons.close))
                ],
              ),
            ));
  }

  Future<bool?> _showExpiryFilterDialog() {
    getData(int days) async {
      planList.clear();
      expiryDaysTOSearch = days;
      searchMode = "expiry";
      setState(() {});
      fetchSearchedProducts();

      Navigator.of(context).pop();
      Navigator.of(context).pop();
    }

    ;

    return showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
              content:
                  Container(height: 350, child: ExpiryFilterContent(getData)),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Select Expiry days'),
                  GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                      },
                      child: Icon(Icons.close))
                ],
              ),
            ));
  }
}

class ExpiryFilterContent extends StatefulWidget {
  var ontap;
  ExpiryFilterContent(this.ontap);

  @override
  State<ExpiryFilterContent> createState() => _RadioButtonGroupState();
}

class _RadioButtonGroupState extends State<ExpiryFilterContent> {
  int groupedValue = 7;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RadioMenuButton(
            value: 7,
            groupValue: groupedValue,
            onChanged: (v) {
              groupedValue = 7;
              setState(() {});
            },
            child: Text("7")),
        RadioMenuButton(
            value: 15,
            groupValue: groupedValue,
            onChanged: (v) {
              groupedValue = 15;
              setState(() {});
            },
            child: Text("15")),
        RadioMenuButton(
            value: 30,
            groupValue: groupedValue,
            onChanged: (v) {
              groupedValue = 30;
              setState(() {});
            },
            child: Text("30")),
        RadioMenuButton(
            value: 90,
            groupValue: groupedValue,
            onChanged: (v) {
              groupedValue = 90;
              setState(() {});
            },
            child: Text("90")),
        RadioMenuButton(
            value: 180,
            groupValue: groupedValue,
            onChanged: (v) {
              groupedValue = 180;
              setState(() {});
            },
            child: Text("180")),
        SizedBox(
          height: 20,
        ),
        CustomTextField(
          inputType: TextInputType.number,
          hintText: "Custom Expiry",
          onChanged: (e) {
            groupedValue = int.parse(e);
          },
        ),
        SizedBox(
          height: 20,
        ),
        CustomButton(
            title: 'Submit',
            onTap: () async {
              widget.ontap(groupedValue);
            }),
      ],
    );
  }
}
