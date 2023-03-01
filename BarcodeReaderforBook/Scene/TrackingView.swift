//
//  TrackingView.swift
//  BarcodeReaderforBook
//
//  Created by amamiya on 2023/02/26.
//

import SwiftUI

struct TrackingView: View {
    @StateObject var viewModel = TrackingViewModel()
    @State private var isShowingCoreDataView: Bool = false
    
    var body: some View {
        #if targetEnvironment(simulator)
            Text("please run on real device.")
        #else
            VStack{
                PreviewLayerView(previewLayer: viewModel.previewLayer, detectedRect: viewModel.detectedRects, pixelSize: viewModel.pixelSize)
                ResultView(viewModel: viewModel)
                BarcodeListView(info: viewModel.info)
                
                
                HStack{
                    Button {
                        
                    } label: {
                        Label("Add", systemImage: "paperplane")
                    }
                    .font(.headline)
                    .foregroundColor(.primary)
                    .padding()
                    .frame(width: 220, height: 60)
                    .background(viewModel.isAdded ? .green: .gray)
                    .cornerRadius(15.0, antialiased: true)
                    .disabled(!viewModel.isAdded)

                    Button {
                        isShowingCoreDataView.toggle()
                    } label: {
                        Label("List", systemImage: "list.bullet.clipboard")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .padding()
                            .background(.blue)
                            .cornerRadius(15.0, antialiased: true)
                    }
                }
            }
            .onAppear{
                viewModel.startSession()
            }
            
        #endif
        
    }
}
// バーコードの読み取り結果
struct BarcodeListView: View {
    let info: [[String:String]]

    var body: some View {
        List{
            Section(header: Text("検出結果"), content: {
                ForEach(info.indices, id: \.self){ index in
                    ForEach(Array(info[index].keys.sorted()), id: \.self) { key in
                        HStack {
                            Text("\(key)")
                            Spacer()
                            Text("\(info[index][key] ?? "")")
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            })
        }
    }
}

struct ResultView: View {
    @StateObject var viewModel: TrackingViewModel
    
    var body: some View {
        List {
            Section {
                ForEach(viewModel.book, id: \.volumeInfo.title) { book in
                    VStack(alignment: .leading) {
                        Text("\(book.volumeInfo.title)")
                    
                    }
                }
            } header: {
                Text("Detected Result")
            }

        }
    }
}
struct TrackingView_Previews: PreviewProvider {
    static var previews: some View {
        TrackingView()
    }
}
