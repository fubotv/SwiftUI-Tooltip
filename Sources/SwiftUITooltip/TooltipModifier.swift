//
//  Tooltip.swift
//
//  Created by Antoni Silvestrovic on 19/10/2020.
//  Copyright © 2020 Quassum Manus. All rights reserved.
//

import SwiftUI

struct TooltipModifier<TooltipContent: View>: ViewModifier {
    // MARK: - Uninitialised properties
    var enabled: Bool
    var config: TooltipConfig
    var content: TooltipContent


    // MARK: - Initialisers

    init(enabled: Bool, config: TooltipConfig, @ViewBuilder content: @escaping () -> TooltipContent) {
        self.enabled = enabled
        self.config = config
        self.content = content()
    }

    // MARK: - Local state

    @State private var contentWidth: CGFloat = 10
    @State private var contentHeight: CGFloat = 10

    @State var xPosition: CGFloat = 0
    @State var yPosition: CGFloat = 0

    @State var opacity: CGFloat = 0

    @State private var hostSize: CGSize = .zero
    @State private var hostGlobalFrame: CGRect = .zero

    // MARK: - Computed properties

    var showArrow: Bool { config.showArrow && config.side.shouldShowArrow() }
    var actualArrowHeight: CGFloat { self.showArrow ? config.arrowHeight : 0 }

    // MARK: - Helper functions

    private func arrowXPosition(_ g: GeometryProxy) -> CGFloat {
        return (contentWidth + g.size.width) / 2 - xPosition(g)
    }

    private func arrowYPosition(_ g: GeometryProxy) -> CGFloat {
        switch config.side {
        case .bottom:
            return (config.borderWidth - actualArrowHeight) / 2
        case .top:
            return contentHeight + (actualArrowHeight - config.borderWidth) / 2
        }
    }

    private func xPosition(_ g: GeometryProxy) -> CGFloat {
        xPosition(hostSize: g.size, hostGlobalFrame: g.frame(in: .global))
    }

    private func xPosition(hostSize: CGSize, hostGlobalFrame: CGRect) -> CGFloat {
        let gutter: CGFloat = config.gutter
        var x: CGFloat = hostSize.width / 2
        if hostGlobalFrame.midX + contentWidth / 2 > UIScreen.main.bounds.width - gutter {
            x -= hostGlobalFrame.midX + contentWidth / 2 - UIScreen.main.bounds.width + gutter
        } else if hostGlobalFrame.midX - contentWidth / 2 < gutter {
            x += contentWidth / 2 - hostGlobalFrame.midX + gutter
        }

        return x
    }

    private func yPosition(_ g: GeometryProxy) -> CGFloat {
        yPosition(hostSize: g.size)
    }

    private func yPosition(hostSize: CGSize) -> CGFloat {
        let offset = contentHeight / 2 + config.borderWidth + actualArrowHeight + config.margin

        if config.side == .top {
            return -offset
        } else {
            return hostSize.height + offset
        }
    }

    private func updateContentSize(_ size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let newWidth = config.width ?? size.width
        let newHeight = config.height ?? size.height
        guard newWidth != contentWidth || newHeight != contentHeight else { return }
        contentWidth = newWidth
        contentHeight = newHeight
        updatePosition()
    }

    private func updateHostGeometry(_ g: GeometryProxy) {
        hostSize = g.size
        hostGlobalFrame = g.frame(in: .global)
        updatePosition()
    }

    private func updatePosition() {
        xPosition = xPosition(hostSize: hostSize, hostGlobalFrame: hostGlobalFrame)
        yPosition = yPosition(hostSize: hostSize)
    }

    // MARK: - TooltipModifier Body Properties

    private var sizeMeasurer: some View {
        GeometryReader { g in
            Color.clear
                .preference(key: TooltipContentSizeKey.self, value: g.size)
        }
    }

    private func arrowView(_ g: GeometryProxy) -> some View {
        guard let arrowAngle = config.side.getArrowAngleRadians() else {
            return AnyView(EmptyView())
        }
        
        return AnyView(ArrowShape()
            .rotation(Angle(radians: arrowAngle))
            .stroke(config.borderColor, lineWidth: config.borderWidth)

            .background(ArrowShape()
                .offset(x: 0, y: 1)
                .rotation(Angle(radians: arrowAngle))
                .frame(width: config.arrowWidth+2, height: config.arrowHeight+1)
                .foregroundColor(config.backgroundColor)
                
            )
                .frame(width: config.arrowWidth, height: config.arrowHeight)
                .position(x: arrowXPosition(g), y: arrowYPosition(g)))
    }

    private func arrowCutoutMask(_ g: GeometryProxy) -> some View {
        guard let arrowAngle = config.side.getArrowAngleRadians() else {
            return AnyView(EmptyView())
        }
        
        return AnyView(
            ZStack {
                Rectangle()
                    .frame(
                        width: self.contentWidth + config.borderWidth * 2,
                        height: self.contentHeight + config.borderWidth * 2)
                    .foregroundColor(.white)
                Rectangle()
                    .frame(
                        width: config.arrowWidth,
                        height: config.arrowHeight + config.borderWidth)
                    .rotationEffect(Angle(radians: arrowAngle))
                    .position(x: arrowXPosition(g) + config.borderWidth, y: arrowYPosition(g) + actualArrowHeight / 2)
                    .foregroundColor(.black)
            }
            .compositingGroup()
            .luminanceToAlpha()
        )
    }
    
    var tooltipBody: some View {
        GeometryReader { g in
            ZStack {
                RoundedRectangle(cornerRadius: config.borderRadius)
                    .strokeBorder(config.borderColor, lineWidth: config.borderWidth)
                    .frame(width: contentWidth, height: contentHeight)
                    .background(
                        RoundedRectangle(cornerRadius: config.borderRadius)
                            .foregroundColor(config.backgroundColor)
                    )
                    .mask(self.arrowCutoutMask(g))
                
                ZStack {
                    content
                        .padding(config.contentPaddingEdgeInsets)
                        .frame(
                            width: config.width,
                            height: config.height
                        )
                        .fixedSize(horizontal: config.width == nil, vertical: true)
                }
                .background(self.sizeMeasurer)
                .overlay(self.arrowView(g))
            }
            .position(x: xPosition, y: yPosition)
            .zIndex(config.zIndex)
            .onPreferenceChange(TooltipContentSizeKey.self) { size in
                updateContentSize(size)
            }
            .onAppear {
                opacity = 0
                updateHostGeometry(g)
            }
            .task {
                updateHostGeometry(g)
                withAnimation {
                    opacity = 1
                }
            }
        }
        .opacity(opacity)
    }

    // MARK: - ViewModifier properties

    func body(content: Content) -> some View {
        content
            .overlay(enabled ? tooltipBody: nil)
    }
}

private struct TooltipContentSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

struct Tooltip_Previews: PreviewProvider {
    static var previews: some View {
        var config = DefaultTooltipConfig(side: .top)
        config.enableAnimation = false        
        
        return VStack {
            Text("Say...").tooltip(config: config) {
                Text("Something nice!")
            }
        }.previewDevice(.init(stringLiteral: "iPhone 12 mini"))
    }
}
